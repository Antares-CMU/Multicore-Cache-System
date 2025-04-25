`include "cache.svh"
// cache coherence bus module
module bus (
  input  logic clk,
  input  logic reset_n,
  // L1 controller interface (for `CPU_CORES L1 modules)
  input  logic [`CPU_CORES-1:0]                     l1_req_valid,
  output logic [`CPU_CORES-1:0]                     l1_req_ready,
  input  logic [`CPU_CORES-1:0][`ADDR_BITS - `OFFSET_BITS - 1:0] l1_req_addr,
  input  bus_req_t [`CPU_CORES-1:0]                 l1_req,
  input  logic [`CPU_CORES-1:0][`CACHELINE_BITS-1:0] l1_req_data,
  output logic                        l1_resp_valid,
  output logic [`CACHELINE_BITS-1:0]  l1_resp_data,
  output logic                        l1_resp_shared,

  // L1 snooper interface (for `CPU_CORES L1 modules)
  output logic [`CPU_CORES-1:0]                     l1_snoop_valid,
  output logic [`ADDR_BITS - `OFFSET_BITS - 1:0]    l1_snoop_addr,
  output bus_req_t                                  l1_snoop_req,
  input  logic [`CPU_CORES-1:0]                     l1_snoop_shared,
  input  logic [`CPU_CORES-1:0][`CACHELINE_BITS-1:0] l1_snoop_data,

  // L2 module interface
  output logic                                    l2_req_valid,
  input  logic                                    l2_req_ready,
  output logic [`ADDR_BITS - `OFFSET_BITS - 1:0]  l2_req_addr,
  output logic                                    l2_req_rw,     // 0: read, 1: write
  output logic [`CACHELINE_BITS-1:0]              l2_req_data,
  input  logic                                    l2_resp_valid,
  input  logic [`CACHELINE_BITS-1:0]              l2_resp_data
);

  // FSM state definition
  typedef enum logic [2:0] {
    IDLE,
    REQ,
    S_REP,
    L2_REQ,
    L2_WAIT,
    L2_REP
  } state_t;

  state_t cur_state, next_state;

  // Registers for bus request, address, and data
  bus_req_t req_reg, next_req;
  logic [`ADDR_BITS - `OFFSET_BITS - 1:0] addr_reg, next_addr;
  logic [`CACHELINE_BITS - 1:0]           data_reg, next_data;
  logic [1:0] cpu_reg, next_cpu;       // CPU ID for L1 request

  // Sequential block: update state and registers on clock edge or reset
  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      cur_state <= IDLE;
      req_reg   <= BUS_RD;
      addr_reg  <= '0;
      data_reg  <= '0;
      cpu_reg   <= 0;
    end else begin
      cur_state <= next_state;
      req_reg   <= next_req;
      addr_reg  <= next_addr;
      data_reg  <= next_data;
      cpu_reg   <= next_cpu;
    end
  end

  // Combinational block: decide next state, next values, and outputs
  always_comb begin
    // Default assignments for FSM registers
    next_state = cur_state;
    next_req   = req_reg;
    next_addr  = addr_reg;
    next_data  = data_reg;
    next_cpu   = cpu_reg;

    // Default assignments for outputs
    l1_req_ready  = '0;
    l1_resp_valid = 1'b0;
    l1_resp_data  = '0;
    l1_snoop_valid = '0;

    // FSM state case analysis
    case(cur_state)
      IDLE: begin
        // Loop over all CPU cores (lower ID has higher priority)
        for (int i = 0; i < `CPU_CORES; i++) begin
          if (l1_req_valid[i]) begin
            l1_req_ready[i] = 1'b1;             // Assert ready for the selected CPU
            next_req   = l1_req[i];             // Store the bus request from L1 controller
            next_addr  = l1_req_addr[i];          // Store the address from L1 controller
            next_data  = l1_req_data[i];          // Store the data from L1 controller
            next_cpu   = i;                     // Record the CPU id
            next_state = REQ;                   // Transition to REQ state
            break;                             // Exit the loop after handling one request
          end
        end
      end

      REQ: begin
        // For each L1 core, assert l1_snoop_valid except for the CPU which originated the request (cpu_reg)
        for (int i = 0; i < `CPU_CORES; i++) begin
          if (i != cpu_reg)
            l1_snoop_valid[i] = 1'b1;
        end

        // Determine next state based on the bus request type
        if (req_reg == BUS_UPGR)
          next_state = IDLE;
        else if (req_reg == BUS_WB)
          next_state = L2_REQ;
        else
          next_state = S_REP;
      end

      S_REP: begin
        // By default, assume no shared response exists so next_state will be L2_REQ if no match is found
        next_state = L2_REQ;
        // Loop through each L1 core; lower ID has higher priority
        for (int i = 0; i < `CPU_CORES; i++) begin
          if (l1_snoop_shared[i]) begin
            l1_resp_valid = 1'b1;
            l1_resp_data  = l1_snoop_data[i];
            next_state    = IDLE;
            break;
          end
        end
      end

      L2_REQ: begin
        if (l2_req_ready) begin
          if (req_reg == BUS_WB)
            next_state = IDLE;
          else
            next_state = L2_WAIT;
        end
      end

      L2_WAIT: begin
        if (l2_resp_valid) begin
          next_state = L2_REP;
          next_data  = l2_resp_data;
        end
      end

      L2_REP: begin
        l1_resp_valid = 1'b1;
        l1_resp_data  = data_reg;
        next_state    = IDLE;
      end

      default: begin
        // Default
      end
    endcase
  end

  // L1 response channel
  assign l1_resp_shared = |l1_snoop_shared;
  // L1 snooper channel
  assign l1_snoop_addr  = addr_reg;
  assign l1_snoop_req   = req_reg;
  // L2 request channel
  assign l2_req_valid = (cur_state == L2_REQ) ? 1'b1 : 1'b0;
  assign l2_req_addr  = addr_reg;
  assign l2_req_rw    = (req_reg == BUS_WB) ? 1'b1 : 1'b0;
  assign l2_req_data  = data_reg;

endmodule : bus
