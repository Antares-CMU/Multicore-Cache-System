`ifndef CACHE_H
    `define CACHE_H
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
    typedef struct {
        moesi_t state;                     // MOESI state
        logic [`L1_TAG_BITS-1:0] tag;              // Tag field
        logic [`CACHELINE_BITS-1:0] cacheline;     // Cacheline data
    } l1_cacheline_t;

    typedef enum logic [1:0] {
        L2_I, // Invalid
        L2_C, // Clean
        L2_D  // Dirty
    } l2_state_t;

    typedef struct {
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

`endif
