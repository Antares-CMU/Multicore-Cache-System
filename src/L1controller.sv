`include "cache.svh"
// L1 controller module
module L1controller (
  input  logic                                  clk,
  input  logic                                  reset_n,
  // CPU request channel (CPU -> controller)
  input  logic                                  cpu_valid,
  input  logic                                  cpu_command,    // load: 0; store: 1
  input  logic [`ADDR_BITS - `OFFSET_BITS - 1:0] cpu_addr,
  input  logic [`CACHELINE_BITS - 1:0]          cpu_write_data,
  output logic                                  cpu_ready,
  // CPU read channel (controller -> CPU)
  output logic                                  cpu_read_valid,
  output logic [`CACHELINE_BITS - 1:0]          cpu_read_data,
  // Bus request channel (controller -> bus)
  output logic                                  bus_req_valid,
  input  logic                                  bus_req_ready,
  output logic [`ADDR_BITS - `OFFSET_BITS - 1:0] bus_req_addr,
  output bus_req_t                              bus_req,
  output logic [`CACHELINE_BITS - 1:0]          bus_req_data,
  // Bus respond channel (bus -> controller)
  input  logic                                  bus_resp_valid,
  input  logic [`CACHELINE_BITS - 1:0]          bus_resp_data,
  input  logic                                  bus_resp_shared,
  // L1cache interface (reversed relative to L1cache)
  output logic [`ADDR_BITS - `OFFSET_BITS - 1:0] cache_addr,
  input  l1_cacheline_t                         cacheline_lookup,  // cache -> controller
  output l1_cacheline_t                         cacheline_update,  // controller -> cache
  output logic                                  update_valid  // controller -> cache
);

  // FSM state definition
  typedef enum logic [2:0] {
    IDLE,
    EVICTION,
    BUS_REQ,
    BUS_WAIT,
    RESPOND
  } state_t;

  // Registers for current state and next state
  state_t cur_state, next_state;

  // Registers to hold CPU command, address, and data from CPU request
  logic       command_reg, next_command;
  logic [`ADDR_BITS - `OFFSET_BITS - 1:0] addr_reg, next_addr;
  logic [`CACHELINE_BITS - 1:0]           data_reg, next_data;

  // Sequential block: update state, command_reg, addr_reg, and data_reg
  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      cur_state         <= IDLE;
      command_reg       <= 1'b0;
      addr_reg          <= '0;
      data_reg          <= '0;
    end else begin
      cur_state         <= next_state;
      command_reg       <= next_command;
      addr_reg          <= next_addr;
      data_reg          <= next_data;
    end
  end

  // Combinational block: decide next state, next_command, next_addr, next_data, and drive outputs
  always_comb begin
    // Default assignments
    next_state      = cur_state;
    next_command    = command_reg;
    next_addr       = addr_reg;
    next_data       = data_reg;
    bus_req_valid   = 0;
    bus_req_addr    = '0;
    bus_req         = BUS_RD;
    cacheline_update = cacheline_lookup;
    update_valid    = 0;

    case (cur_state)
      IDLE: begin
        if (cpu_valid) begin
          // Record current CPU request values into registers
          next_command = cpu_command;
          next_addr    = cpu_addr;
          next_data    = cpu_write_data;
          // Check if eviction is required
          if ((cacheline_lookup.tag != cpu_addr[`ADDR_BITS - `OFFSET_BITS - 1:`L1_INDEX_BITS]) &&
              (cacheline_lookup.state != I)) begin
            next_state = EVICTION;
          end
          // Check if a bus action is needed:
          //   - For load on I state
          //   - For store on I, S, or O state
          else if (((cpu_command == 0) && (cacheline_lookup.state == I)) ||
                  ((cpu_command == 1) && ((cacheline_lookup.state == I) ||
                                            (cacheline_lookup.state == S) ||
                                            (cacheline_lookup.state == O)))) begin
            next_state = BUS_REQ;
          end
          // Otherwise, respond immediately
          else begin
            next_state = RESPOND;
            if (cpu_command == 0) begin // Load
              next_data = cacheline_lookup.cacheline;
            end else begin // Store
              cacheline_update.cacheline = cpu_write_data;
              cacheline_update.state   = M;
              update_valid             = 1;
            end
          end
        end
      end

      EVICTION: begin
        if ((cacheline_lookup.state == I) ||
            (cacheline_lookup.state == S) ||
            (cacheline_lookup.state == E)) begin
          next_state = BUS_REQ;
          cacheline_update.state = I;
          update_valid = 1;
        end
        else if ((cacheline_lookup.state == O) ||
                (cacheline_lookup.state == M)) begin
          // Write back the cacheline to memory
          bus_req_valid = 1;
          bus_req_addr = { cacheline_lookup.tag, addr_reg[`L1_INDEX_BITS-1:0] };
          bus_req = BUS_WB;
          if (bus_req_ready) begin
            next_state = BUS_REQ;
            cacheline_update.state = I;
            update_valid = 1;
          end
        end
      end

      BUS_REQ: begin
        bus_req_valid = 1;
        bus_req_addr = addr_reg;
        if (cacheline_lookup.state == I) begin
          if (command_reg == 0) begin // Load command
            bus_req = BUS_RD;
          end else begin   // Store command
            bus_req = BUS_RDX;
          end
        end
        else begin
          bus_req = BUS_UPGR;
        end
        if (bus_req_ready) begin
          if (bus_req == BUS_UPGR) begin
            next_state = RESPOND;
            cacheline_update.state = M;
            cacheline_update.cacheline = data_reg;
            update_valid = 1;
          end
          else begin
            next_state = BUS_WAIT;
          end
        end
      end

      BUS_WAIT: begin
        if (bus_resp_valid) begin
          next_state = RESPOND;
          next_data  = bus_resp_data;
          if (command_reg == 0) begin // Load command
            // Update cacheline state based on bus_resp_shared signal
            if (bus_resp_shared) begin
              cacheline_update.state = S;
            end else begin
              cacheline_update.state = E;
            end
            cacheline_update.cacheline = bus_resp_data;
            cacheline_update.tag    = addr_reg[`ADDR_BITS - `OFFSET_BITS - 1:`L1_INDEX_BITS];
            update_valid = 1;
          end else begin // Store command
            cacheline_update.cacheline = data_reg;
            cacheline_update.tag    = addr_reg[`ADDR_BITS - `OFFSET_BITS - 1:`L1_INDEX_BITS];
            cacheline_update.state   = M;
            update_valid             = 1;
          end
        end
      end

      RESPOND: begin
        next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end


  assign cpu_ready = (cur_state == IDLE);
  assign cpu_read_valid = (cur_state == RESPOND);
  assign cpu_read_data = data_reg;
  assign bus_req_data = cacheline_lookup.cacheline;
  assign cache_addr = (cur_state == IDLE) ? cpu_addr : addr_reg;
  
endmodule : L1controller
