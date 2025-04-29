`include "cache.svh"
// L2 controller module
module L2controller (
  input  logic                                   clk,
  input  logic                                   reset_n,

  // L2cache interface (reversed relative to L2cache module)
  output logic [`ADDR_BITS - `OFFSET_BITS - 1:0]  cache_addr,
  output l2_cacheline_t                           cacheline_update,
  output logic                                   cache_valid,  // signals an update to L2cache
  input  l2_cacheline_t                           cacheline_lookup,

  // Bus interface (reversed relative to L2 module interface to bus)
  input  logic                                   l2_req_valid,
  output logic                                   l2_req_ready,
  input  logic [`ADDR_BITS - `OFFSET_BITS - 1:0]  l2_req_addr,
  input  logic                                   l2_req_rw,     // 0: read, 1: write
  input  logic [`CACHELINE_BITS-1:0]             l2_req_data,
  output logic                                   l2_resp_valid,
  output logic [`CACHELINE_BITS-1:0]             l2_resp_data,

  // Main memory request channel
  // Main memory request channel signals:
  //   valid, rw, addr, data, ready
  // L2controller -> Main memory (outputs from controller, inputs from memory):
  output logic                                   mem_req_valid,
  output logic                                   mem_req_rw,    // 0: read, 1: write
  output logic [`ADDR_BITS - `OFFSET_BITS - 1:0]  mem_req_addr,
  output logic [`CACHELINE_BITS-1:0]             mem_req_data,
  input  logic                                   mem_req_ready,

  // Main memory response channel
  // Main memory response channel signals:
  //   valid, data (from memory to controller)
  input  logic                                   mem_resp_valid,
  input  logic [`CACHELINE_BITS-1:0]             mem_resp_data
);

  // FSM state definition for L2controller
  typedef enum logic [2:0] {
    IDLE,
    EVICTION,
    MM_REQ,
    WAIT,
    RESPOND
  } state_t;

  state_t cur_state, next_state;

  // Registers for memory interface signals
  logic rw_reg, next_rw;
  logic [`ADDR_BITS - `OFFSET_BITS - 1:0] addr_reg, next_addr;
  logic [`CACHELINE_BITS-1:0] data_reg, next_data;

  // Sequential block: update state and registers on clock edge or reset
  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      cur_state <= IDLE;
      rw_reg    <= 1'b0;
      addr_reg  <= '0;
      data_reg  <= '0;
    end else begin
      cur_state <= next_state;
      rw_reg    <= next_rw;
      addr_reg  <= next_addr;
      data_reg  <= next_data;
    end
  end

  // Combinational block: next state and output logic
  always_comb begin
    // Default assignments for FSM registers
    next_state = cur_state;
    next_rw    = rw_reg;
    next_addr  = addr_reg;
    next_data  = data_reg;

    // Default assignments for L2cache update outputs
    cache_valid = 1'b0;
    cacheline_update    = cacheline_lookup;

    case (cur_state)
      IDLE: begin
        if (l2_req_valid) begin
          // Extract tag from l2_req_addr: use upper bits of the address
          logic [`L2_TAG_BITS-1:0] req_tag;
          req_tag = l2_req_addr[(`ADDR_BITS - `OFFSET_BITS) - 1 -: `L2_TAG_BITS];

          if (l2_req_rw && ( (cacheline_lookup.tag == req_tag) || (cacheline_lookup.state != L2_D) )) begin
            // Write hit or write on invalid/Clean: update L2 cache line to Dirty
            next_state = IDLE;
            cacheline_update.state    = L2_D;
            cacheline_update.tag      = req_tag;
            cacheline_update.cacheline = l2_req_data;
            cache_valid = 1'b1;
          end else if (!l2_req_rw &&
                       ((cacheline_lookup.state == L2_C) || (cacheline_lookup.state == L2_D)) &&
                       (cacheline_lookup.tag == req_tag)) begin
            // Read hit: respond immediately with the cacheline content
            next_state = RESPOND;
            next_data  = cacheline_lookup.cacheline;
          end else if ((cacheline_lookup.state == L2_D) && (cacheline_lookup.tag != req_tag)) begin
            // Eviction required: current dirty line's tag mismatches request
            next_state = EVICTION;
            next_rw    = l2_req_rw;
            next_addr  = l2_req_addr;
            next_data  = l2_req_data;
          end else begin
            // Read miss, issue a memory request
            next_state = MM_REQ;
            next_rw    = l2_req_rw;
            next_addr  = l2_req_addr;
            next_data  = l2_req_data;
          end
        end
      end

      EVICTION: begin
        if (mem_req_ready) begin
          if (rw_reg) begin
            next_state = IDLE;
            cacheline_update.state    = L2_D;
            cacheline_update.tag      = addr_reg[(`ADDR_BITS - `OFFSET_BITS) - 1 -: `L2_TAG_BITS];
            cacheline_update.cacheline = data_reg;
            cache_valid               = 1'b1;
          end else begin
            next_state = MM_REQ;
            cacheline_update.state = L2_I;
            cache_valid            = 1'b1;
          end
        end
      end

      MM_REQ: begin
        if (mem_req_ready)
          next_state = WAIT;
      end

      WAIT: begin
        if (mem_resp_valid) begin
          next_state = RESPOND;
          cacheline_update.state    = L2_C;
          cacheline_update.tag      = addr_reg[(`ADDR_BITS - `OFFSET_BITS) - 1 -: `L2_TAG_BITS];
          cacheline_update.cacheline = mem_resp_data;
          cache_valid               = 1'b1;
          next_data                = mem_resp_data;
        end else begin
          next_state = WAIT;
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

  // Output Logic
  assign cache_addr = (cur_state == IDLE) ? l2_req_addr : addr_reg;
  assign l2_req_ready = (cur_state == IDLE);
  assign l2_resp_valid = (cur_state == RESPOND);
  assign l2_resp_data = data_reg;
  assign mem_req_valid = (cur_state == MM_REQ) || (cur_state == EVICTION);
  assign mem_req_rw = (cur_state == EVICTION);
  assign mem_req_addr = (cur_state == EVICTION) ? {cacheline_lookup.tag, addr_reg[`L2_INDEX_BITS-1:0]} : addr_reg;
  assign mem_req_data = (cur_state == EVICTION) ? cacheline_lookup.cacheline : data_reg;

endmodule : L2controller
