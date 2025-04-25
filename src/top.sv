`include "cache.svh"
// Top-level module for a multi-core cache system with L1 and L2 caches
module top (
  input  logic                                   clk,
  input  logic                                   reset_n,
  // CPU interfaces for `CPU_CORES cores
  input  logic [`CPU_CORES-1:0]                  cpu_valid,
  input  logic [`CPU_CORES-1:0]                  cpu_command,     // load: 0; store: 1
  input  logic [`CPU_CORES*(`ADDR_BITS - `OFFSET_BITS)-1:0] cpu_addr,
  input  logic [`CPU_CORES*`CACHELINE_BITS-1:0]  cpu_write_data,
  output logic [`CPU_CORES-1:0]                  cpu_ready,
  output logic [`CPU_CORES-1:0]                  cpu_read_valid,
  output logic [`CPU_CORES*`CACHELINE_BITS-1:0]  cpu_read_data,
  // Main Memory interface
  output logic                                   mem_req_valid,
  output logic                                   mem_req_rw,      // 0: read; 1: write
  output logic [`ADDR_BITS - `OFFSET_BITS - 1:0] mem_req_addr,
  output logic [`CACHELINE_BITS - 1:0]           mem_req_data,
  input  logic                                   mem_req_ready,
  input  logic                                   mem_resp_valid,
  input  logic [`CACHELINE_BITS - 1:0]           mem_resp_data
);

  //-------------------------------------------------------------------------
  // Internal wires for connecting L1 modules to the bus module
  // L1 controller interface (outputs from L1 and inputs to bus)
  logic [`CPU_CORES-1:0]                     l1_req_valid;
  logic [`CPU_CORES-1:0]                     l1_req_ready;
  logic [`CPU_CORES*(`ADDR_BITS - `OFFSET_BITS)-1:0] l1_req_addr;
  bus_req_t [`CPU_CORES-1:0]                 l1_req;
  logic [`CPU_CORES*`CACHELINE_BITS-1:0]     l1_req_data;

  // L1 response signals from bus (driven by bus, consumed by L1)
  logic                                      l1_resp_valid;
  logic [`CACHELINE_BITS-1:0]                l1_resp_data;
  logic                                      l1_resp_shared;

  // L1 snooper interface (signals from bus to each L1's snoop inputs)
  logic [`CPU_CORES-1:0]                     l1_snoop_valid;
  logic [`ADDR_BITS - `OFFSET_BITS - 1:0]    l1_snoop_addr;
  bus_req_t                                  l1_snoop_req;
  logic [`CPU_CORES-1:0]                     l1_snoop_shared;
  logic [`CPU_CORES*`CACHELINE_BITS-1:0]     l1_snoop_data;

  //-------------------------------------------------------------------------
  // Internal wires for connecting bus and L2 module
  logic                                    l2_req_valid;
  logic                                    l2_req_ready;
  logic [`ADDR_BITS - `OFFSET_BITS - 1:0]  l2_req_addr;
  logic                                    l2_req_rw;
  logic [`CACHELINE_BITS-1:0]              l2_req_data;
  logic                                    l2_resp_valid;
  logic [`CACHELINE_BITS-1:0]              l2_resp_data;

  //-------------------------------------------------------------------------
  // Instantiate L1 modules for each CPU core
  genvar i;
  generate
    for (i = 0; i < `CPU_CORES; i++) begin : L1_ARRAY
      L1 l1_inst (
        .clk             (clk),
        .reset_n         (reset_n),
        // CPU interface
        .cpu_valid       (cpu_valid[i]),
        .cpu_command     (cpu_command[i]),
        .cpu_addr        (cpu_addr[i*(`ADDR_BITS - `OFFSET_BITS) +: (`ADDR_BITS - `OFFSET_BITS)]),
        .cpu_write_data  (cpu_write_data[i*`CACHELINE_BITS +: `CACHELINE_BITS]),
        .cpu_ready       (cpu_ready[i]),
        .cpu_read_valid  (cpu_read_valid[i]),
        .cpu_read_data   (cpu_read_data[i*`CACHELINE_BITS +: `CACHELINE_BITS]),
        // Bus interface for controller
        .bus_req_valid   (l1_req_valid[i]),
        .bus_req_ready   (l1_req_ready[i]),
        .bus_req_addr    (l1_req_addr[i*(`ADDR_BITS - `OFFSET_BITS) +: (`ADDR_BITS - `OFFSET_BITS)]),
        .bus_req         (l1_req[i]),
        .bus_req_data    (l1_req_data[i*`CACHELINE_BITS +: `CACHELINE_BITS]),
        .bus_resp_valid  (l1_resp_valid),
        .bus_resp_data   (l1_resp_data),
        .bus_resp_shared (l1_resp_shared),
        // Bus snooping interface for snooper
        .snoop_valid     (l1_snoop_valid[i]),
        .snoop_addr      (l1_snoop_addr),
        .snoop_req       (l1_snoop_req),
        .snoop_shared    (l1_snoop_shared[i]),
        .snoop_data      (l1_snoop_data[i*`CACHELINE_BITS +: `CACHELINE_BITS])
      );
    end
  endgenerate

  //-------------------------------------------------------------------------
  // Instantiate bus module
  bus bus_inst (
    .clk               (clk),
    .reset_n           (reset_n),
    // L1 controller interface (aggregate signals from all L1 modules)
    .l1_req_valid      (l1_req_valid),
    .l1_req_ready      (l1_req_ready),
    .l1_req_addr       (l1_req_addr),
    .l1_req            (l1_req),
    .l1_req_data       (l1_req_data),
    .l1_resp_valid     (l1_resp_valid),
    .l1_resp_data      (l1_resp_data),
    .l1_resp_shared    (l1_resp_shared),
    // L1 snooper interface
    .l1_snoop_valid    (l1_snoop_valid),
    .l1_snoop_addr     (l1_snoop_addr),
    .l1_snoop_req      (l1_snoop_req),
    .l1_snoop_shared   (l1_snoop_shared),
    .l1_snoop_data     (l1_snoop_data),
    // L2 module interface
    .l2_req_valid      (l2_req_valid),
    .l2_req_ready      (l2_req_ready),
    .l2_req_addr       (l2_req_addr),
    .l2_req_rw         (l2_req_rw),
    .l2_req_data       (l2_req_data),
    .l2_resp_valid     (l2_resp_valid),
    .l2_resp_data      (l2_resp_data)
  );

  //-------------------------------------------------------------------------
  // Instantiate L2 module
  L2 l2_inst (
    .clk               (clk),
    .reset_n           (reset_n),
    // Bus interface for L2 (to bus)
    .l2_req_valid      (l2_req_valid),
    .l2_req_ready      (l2_req_ready),
    .l2_req_addr       (l2_req_addr),
    .l2_req_rw         (l2_req_rw),
    .l2_req_data       (l2_req_data),
    .l2_resp_valid     (l2_resp_valid),
    .l2_resp_data      (l2_resp_data),
    // Main memory interface
    .mem_req_valid     (mem_req_valid),
    .mem_req_rw        (mem_req_rw),
    .mem_req_addr      (mem_req_addr),
    .mem_req_data      (mem_req_data),
    .mem_req_ready     (mem_req_ready),
    .mem_resp_valid    (mem_resp_valid),
    .mem_resp_data     (mem_resp_data)
  );

endmodule : top
