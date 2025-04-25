`include "cache.svh"
// The module to handle bus snooping for the L1 cache
module L1snooper (
  input  logic                              clk,
  input  logic                              reset_n,
  // Bus snooping channel (bus -> cache)
  input  logic                              valid,
  input  logic [`ADDR_BITS - `OFFSET_BITS - 1:0] addr,
  input  bus_req_t                          req,
  // Snooping respond channel (cache -> bus)
  output logic                              shared,
  output logic [`CACHELINE_BITS - 1:0]        data,
  // cache interface (reversed relative to L1cache)
  output logic [`ADDR_BITS - `OFFSET_BITS - 1:0] cache_addr, 
  input  l1_cacheline_t                     cacheline_lookup,  // cache -> snooper
  output l1_cacheline_t                     cacheline_update,  // snooper -> cache
  output logic                              update_valid  // snooper -> cache
);

  // FSM state definition
  typedef enum logic {
    SNOOPING,
    RESPOND
  } state_t;

  // Registers for FSM state and data output
  state_t cur_state, next_state;
  // 'data' is already declared as output logic, we use it as a register
  logic [`CACHELINE_BITS - 1:0] next_data;

  // Sequential block: update state and data registers
  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      cur_state <= SNOOPING;
      data      <= '0; // Reset data register to zero
    end else begin
      cur_state <= next_state;
      data      <= next_data;
    end
  end

  // Combinational block: decide next state, next_data, cacheline_update, and update_valid
  always_comb begin
    // Default assignments
    next_state       = cur_state;
    next_data        = data;
    cacheline_update = cacheline_lookup;
    update_valid     = 0;

    if (cur_state == SNOOPING) begin
      if (valid && (cacheline_lookup.tag == addr[`ADDR_BITS - `OFFSET_BITS - 1:`L1_INDEX_BITS]) && (cacheline_lookup.state != I)) begin
        case (req)
          BUS_WB: begin
            // Do nothing for BUS_WB
            next_state = SNOOPING;
          end
          BUS_UPGR: begin
            // Invalidate the cacheline in all cases (S, E, O, M)
            // though only S & O states are possible to be here
            cacheline_update.state = I;
            update_valid = 1;
            next_state = SNOOPING;
          end
          BUS_RD: begin
            // In all cases (S, E, O, M) supply data via bus response
            next_data = cacheline_lookup.cacheline;
            next_state = RESPOND;
            // For E and M, update state accordingly
            if (cacheline_lookup.state == E) begin
              cacheline_update.state = S;
              update_valid = 1;
            end else if (cacheline_lookup.state == M) begin
              cacheline_update.state = O;
              update_valid = 1;
            end
          end
          BUS_RDX: begin
            // Invalidate the cacheline in all cases
            cacheline_update.state = I;
            update_valid = 1;
            // For S state, do nothing on bus
            if (cacheline_lookup.state == S) begin
              next_state = SNOOPING;
            end else begin
              // For E, O, and M, supply data
              next_data = cacheline_lookup.cacheline;
              next_state = RESPOND;
            end
          end
          default: begin
            next_state = SNOOPING;
          end
        endcase
      end else begin
        // If not valid or tag doesn't match or I state, remain in SNOOPING
        next_state = SNOOPING;
      end
    end else begin
      // In RESPOND state, do nothing and transition back to SNOOPING
      next_state = SNOOPING;
    end 
  end

  assign cache_addr = addr;
  assign shared = (cur_state == RESPOND) ? 1 : 0;

endmodule : L1snooper
