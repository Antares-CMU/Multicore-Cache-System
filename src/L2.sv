`define ADDR_BITS 8
`define L1_TAG_BITS 4
`define L1_INDEX_BITS 2
`define OFFSET_BITS 2
`define L2_TAG_BITS 2
`define L2_INDEX_BITS 4
`define CACHELINE_BITS 1
`define CPU_CORES 4

// Define MOESI states as a 3-bit enumerated type
typedef enum logic [2:0] {
    I, // Invalid
    S, // Shared
    E, // Exclusive
    O, // Owned
    M  // Modified
} moesi_t;

// Define the L1 cacheline struct with MOESI state, tag, and cacheline data
typedef struct packed {
    moesi_t state;                     // MOESI state
    logic [`L1_TAG_BITS-1:0] tag;              // Tag field
    logic [`CACHELINE_BITS-1:0] cacheline;     // Cacheline data
} l1_cacheline_t;

typedef enum logic [1:0] {
    L2_I, // Invalid
    L2_C, // Clean
    L2_D  // Dirty
} l2_state_t;

typedef struct packed {
    l2_state_t state;                               // L2 state (Invalid, Clean, Dirty)
    logic [`L2_TAG_BITS-1:0] tag;                   // Tag field
    logic [`CACHELINE_BITS-1:0] cacheline;          // Cacheline data
} l2_cacheline_t;

typedef enum logic [1:0] {
    BUS_RD,  // Bus Read: Request to read data from cache or memory
    BUS_RDX,  // Bus Read-Exclusive: Read with intent to modify
    BUS_UPGR,  // Bus Upgrade: Upgrade a shared cache line to modified state
    BUS_WB   // Bus Write-Back: Write modified data back to memory
} bus_req_t;

// L2 top module
module L2 (
  input  logic                                   clk,
  input  logic                                   reset_n,
  // Bus interface for L2 (to bus)
  input  logic                                   l2_req_valid,
  output logic                                   l2_req_ready,
  input  logic  [`ADDR_BITS - `OFFSET_BITS - 1:0] l2_req_addr,
  input  logic                                   l2_req_rw,      // 0: read, 1: write
  input  logic  [`CACHELINE_BITS-1:0]            l2_req_data,
  output logic                                   l2_resp_valid,
  output logic  [`CACHELINE_BITS-1:0]            l2_resp_data,
  // Main memory interface
  output logic                                   mem_req_valid,
  output logic                                   mem_req_rw,     // 0: read, 1: write
  output logic  [`ADDR_BITS - `OFFSET_BITS - 1:0] mem_req_addr,
  output logic  [`CACHELINE_BITS-1:0]            mem_req_data,
  input  logic                                   mem_req_ready,
  input  logic                                   mem_resp_valid,
  input  logic  [`CACHELINE_BITS-1:0]            mem_resp_data
);

  // Internal signals to connect L2controller with L2cache
  logic [`ADDR_BITS - `OFFSET_BITS - 1:0] cache_addr;
  l2_cacheline_t                           cacheline_update;
  logic                                    cache_valid;
  l2_cacheline_t                           cacheline_lookup;

  // Instantiate L2cache
  L2cache cache_inst (
    .addr              (cache_addr),
    .clk               (clk),
    .reset_n           (reset_n),
    .cacheline_update  (cacheline_update),
    .valid             (cache_valid),
    .cacheline_lookup  (cacheline_lookup)
  );

  // Instantiate L2controller
  L2controller ctrl_inst (
    .clk                (clk),
    .reset_n            (reset_n),
    // L2cache interface (reversed relative to L2cache module)
    .cache_addr         (cache_addr),
    .cacheline_update   (cacheline_update),
    .cache_valid        (cache_valid),
    .cacheline_lookup   (cacheline_lookup),
    // Bus interface (reversed relative to L2 module interface to bus)
    .l2_req_valid       (l2_req_valid),
    .l2_req_ready       (l2_req_ready),
    .l2_req_addr        (l2_req_addr),
    .l2_req_rw          (l2_req_rw),
    .l2_req_data        (l2_req_data),
    .l2_resp_valid      (l2_resp_valid),
    .l2_resp_data       (l2_resp_data),
    // Main memory request channel
    .mem_req_valid      (mem_req_valid),
    .mem_req_rw         (mem_req_rw),
    .mem_req_addr       (mem_req_addr),
    .mem_req_data       (mem_req_data),
    .mem_req_ready      (mem_req_ready),
    // Main memory response channel
    .mem_resp_valid     (mem_resp_valid),
    .mem_resp_data      (mem_resp_data)
  );

endmodule : L2
