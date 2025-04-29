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

// The module to simulate the L2 cache memory
module L2cache (
  input  logic [`ADDR_BITS - `OFFSET_BITS - 1:0] addr,
  input  logic                                   clk,
  input  logic                                   reset_n,
  // Inputs for cacheline updates
  input  l2_cacheline_t                          cacheline_update,
  input  logic                                   valid,
  // Outputs for cacheline reads
  output l2_cacheline_t                          cacheline_lookup
);

  // Calculate number of cache lines: 2^`L1_INDEX_BITS
  localparam int NUM_LINES = 1 << `L2_INDEX_BITS;

  // Storage for cache lines and a next state temporary array
  l2_cacheline_t cache_mem   [0:NUM_LINES-1];
  l2_cacheline_t cache_next  [0:NUM_LINES-1];

  // Sequential block: update all cachelines on clock edge and handle reset
  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      // On reset, set each cacheline's state to Invalid (I) and clear other fields
      for (int i = 0; i < NUM_LINES; i++) begin
        cache_mem[i].state     <= L2_I; // Reset state set to I
        cache_mem[i].tag       <= '0;
        cache_mem[i].cacheline <= '0;
      end
    end else begin
      // Update cache memory with the computed next state
      cache_mem <= cache_next;
    end
  end

  // Cacheline update logic: if valid, update the cacheline with the new data
  always_comb begin
    cache_next = cache_mem; // Default to current state
    if (valid) begin
      cache_next[addr[`L2_INDEX_BITS-1:0]] = cacheline_update;
    end
  end

  // output logic
  assign cacheline_lookup = cache_mem[addr[`L2_INDEX_BITS-1:0]];

endmodule : L2cache
