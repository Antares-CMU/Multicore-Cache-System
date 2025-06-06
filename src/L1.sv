`include "cache.svh"
// L1 top module
module L1 (
  input  logic                                  clk,
  input  logic                                  reset_n,
  // CPU interface
  input  logic                                  cpu_valid,
  input  logic                                  cpu_command,    // load: 0; store: 1
  input  logic [`ADDR_BITS - `OFFSET_BITS - 1:0] cpu_addr,
  input  logic [`CACHELINE_BITS - 1:0]          cpu_write_data,
  output logic                                  cpu_ready,
  output logic                                  cpu_read_valid,
  output logic [`CACHELINE_BITS - 1:0]          cpu_read_data,
  // Bus interface for controller
  output logic                                  bus_req_valid,
  input  logic                                  bus_req_ready,
  output logic [`ADDR_BITS - `OFFSET_BITS - 1:0] bus_req_addr,
  output bus_req_t                              bus_req,
  output logic [`CACHELINE_BITS - 1:0]          bus_req_data,
  input  logic                                  bus_resp_valid,
  input  logic [`CACHELINE_BITS - 1:0]          bus_resp_data,
  input  logic                                  bus_resp_shared,
  // Bus snooping interface for snooper
  input  logic                                  snoop_valid,
  input  logic [`ADDR_BITS - `OFFSET_BITS - 1:0] snoop_addr,
  input  bus_req_t                              snoop_req,
  output logic                                  snoop_shared,
  output logic [`CACHELINE_BITS - 1:0]          snoop_data
);

  // Internal wires connecting L1controller and L1cache (control side)
  logic [`ADDR_BITS - `OFFSET_BITS - 1:0] ctrl_cache_addr;
  l1_cacheline_t                          cache_ctrl_line;
  l1_cacheline_t                          ctrl_cacheline_update;
  logic                                   ctrl_update_valid;

  // Internal wires connecting L1snooper and L1cache (snoop side)
  logic [`ADDR_BITS - `OFFSET_BITS - 1:0] snoop_cache_addr;
  l1_cacheline_t                          cache_snoop_line;
  l1_cacheline_t                          snoop_cacheline_update;
  logic                                   snoop_update_valid;

  // Instantiate L1cache
  L1cache cache_inst (
    .addr_ctrl         (ctrl_cache_addr),
    .addr_snoop        (snoop_cache_addr),
    .clk               (clk),
    .reset_n           (reset_n),
    .cacheline_ctrl_in (ctrl_cacheline_update),
    .ctrl_valid        (ctrl_update_valid),
    .cacheline_snoop_in(snoop_cacheline_update),
    .snoop_valid       (snoop_update_valid),
    .cacheline_ctrl_out(cache_ctrl_line),
    .cacheline_snoop_out(cache_snoop_line)
  );

  // Instantiate L1controller
  L1controller ctrl_inst (
    .clk               (clk),
    .reset_n           (reset_n),
    // CPU request channel
    .cpu_valid         (cpu_valid),
    .cpu_command       (cpu_command),
    .cpu_addr          (cpu_addr),
    .cpu_write_data    (cpu_write_data),
    .cpu_ready         (cpu_ready),
    // CPU read channel
    .cpu_read_valid    (cpu_read_valid),
    .cpu_read_data     (cpu_read_data),
    // Bus request channel
    .bus_req_valid     (bus_req_valid),
    .bus_req_ready     (bus_req_ready),
    .bus_req_addr      (bus_req_addr),
    .bus_req           (bus_req),
    .bus_req_data      (bus_req_data),
    // Bus respond channel
    .bus_resp_valid    (bus_resp_valid),
    .bus_resp_data     (bus_resp_data),
    .bus_resp_shared   (bus_resp_shared),
    // L1cache interface (control side)
    .cache_addr        (ctrl_cache_addr),
    .cacheline_lookup  (cache_ctrl_line),
    .cacheline_update  (ctrl_cacheline_update),
    .update_valid      (ctrl_update_valid)
  );

  // Instantiate L1snooper
  L1snooper snoop_inst (
    .clk               (clk),
    .reset_n           (reset_n),
    // Bus snooping channel (bus -> cache)
    .valid             (snoop_valid),
    .addr              (snoop_addr),
    .req               (snoop_req),
    // Snooping respond channel (cache -> bus)
    .shared            (snoop_shared),
    .data              (snoop_data),
    // L1cache interface (snoop side)
    .cache_addr        (snoop_cache_addr),
    .cacheline_lookup  (cache_snoop_line),
    .cacheline_update  (snoop_cacheline_update),
    .update_valid      (snoop_update_valid)
  );

endmodule : L1
