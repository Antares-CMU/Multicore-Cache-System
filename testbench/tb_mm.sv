`include "cache.svh"
// The module to simulate main memory
module main_memory (
  input  logic                                          clk,
  input  logic                                          reset_n,
  // Memory request interface from the top module:
  input  logic                                          mem_req_valid,
  input  logic                                          mem_req_rw,      // 0: read; 1: write
  input  logic [`ADDR_BITS - `OFFSET_BITS - 1:0]         mem_req_addr,
  input  logic [`CACHELINE_BITS - 1:0]                    mem_req_data,
  output logic                                          mem_req_ready,
  // Memory response interface to the top module:
  output logic                                          mem_resp_valid,
  output logic [`CACHELINE_BITS - 1:0]                    mem_resp_data
);

  // Calculate the memory size based on address width
  localparam MEM_SIZE = 1 << (`ADDR_BITS - `OFFSET_BITS);
  
  // Declare the memory array
  logic [`CACHELINE_BITS-1:0] memory [0:MEM_SIZE-1];

  // Initialize memory and signals
  integer i;
  initial begin
    for (i = 0; i < MEM_SIZE; i = i + 1) begin
      memory[i] = '0;
    end
    mem_resp_valid <= 1'b0;
    mem_resp_data  <= '0;
    mem_req_ready <= 1'b1;
  end

  // --------------------------------------------------------------------------
  // Testbench‑style main‑memory model
  //   • Accepts a request when mem_req_ready && mem_req_valid
  //   • mem_req_rw is only valid in the cycle mem_req_valid is high, so the
  //     value (together with address and data) is captured immediately.
  // --------------------------------------------------------------------------
  logic          rw_l;
  logic [`ADDR_BITS - `OFFSET_BITS - 1:0] addr_l;
  logic [`CACHELINE_BITS - 1:0] data_l;

  initial begin
    // Reset outputs.
    mem_req_ready  <= 1'b1;     // Ready to accept the very first request
    mem_resp_valid <= 1'b0;
    mem_resp_data  <= '0;

    // Wait until reset_n is released
    wait (reset_n == 1);

    // Main service loop
    forever begin
      @(posedge clk);

      // ---------------------- Handshake ----------------------
      if (mem_req_ready && mem_req_valid) begin
        // Capture the request *once*.
        rw_l   = mem_req_rw;    // 1 = write, 0 = read
        addr_l = mem_req_addr;
        data_l = mem_req_data;

        // Stall further requests
        mem_req_ready <= 1'b0;

        // ----------------- Latency emulation -----------------
        repeat (10) @(posedge clk);

        // -------------------- READ ----------------------
        if (!rw_l) begin
          mem_resp_data  <= memory[addr_l];
          mem_resp_valid <= 1'b1;
          $display("Time %0t: Main Memory READ addr=%h → data=%h",
                  $time, addr_l, memory[addr_l]);
          @(posedge clk);
          mem_resp_valid <= 1'b0;
        end
        // -------------------- WRITE ----------------------
        else begin
          memory[addr_l] = data_l; 
          $display("Time %0t: Main Memory WRITE addr=%h ← data=%h",
                  $time, addr_l, data_l);
        end

        // Ready for the next request
        mem_req_ready <= 1'b1;
      end
    end
  end

endmodule : main_memory
