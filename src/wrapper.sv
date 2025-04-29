// -----------------------------------------------------------------------------
// 6‑phase serial wrapper (12‑bit I/O) for top module
// Phases: 0 1 2 3 4 5
// top_clk: high 4‑5‑0, low 1‑2‑3
// -----------------------------------------------------------------------------
module wrapper (
    input  logic        clk,        // fast system clock
    input  logic        reset_n,    // async-low reset
    input  logic [11:0] in_bits,    // serial input  (12 bits)
    output logic [11:0] out_bits    // serial output (12 bits)
);

    // ---------------------------------------------------------------------
    // 1.  ÷6 clock generator for the DUT
    // ---------------------------------------------------------------------
    logic [2:0] phase;                    // 0‑5

    always_ff @(posedge clk or negedge reset_n)
        if (!reset_n) phase <= 3'd0;
        else          phase <= (phase == 3'd5) ? 3'd0 : phase + 3'd1;

    // low  : 1‑2‑3   high : 4‑5‑0
    logic top_clk = (phase == 3'd4) || (phase == 3'd5) || (phase == 3'd0);

    // ---------------------------------------------------------------------
    // 2.  Three 12‑bit capture registers (36 bits total) — flattened
    //     Segments cap0/1/2 correspond to phases 0/1/2
    // ---------------------------------------------------------------------
    logic [35:0] cap;                     // {cap2,cap1,cap0}

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) cap <= '0;
        else case (phase)
            3'd0: cap[11:0]  <= in_bits;   // cpu_valid|cmd|wr_data
            3'd1: cap[23:12] <= in_bits;   // addr0, addr1
            3'd2: cap[35:24] <= in_bits;   // addr2, addr3
            default: ;                     // phase 3 is direct‑wired
        endcase
    end

    // ---------------------------------------------------------------------
    // 3.  Decode the 30 useful input bits for `top`
    // ---------------------------------------------------------------------
    // cap[0] segment = cap[11:0]
    logic [3:0] cpu_valid      = cap[11:8];
    logic [3:0] cpu_command    = cap[7:4];
    logic [3:0] cpu_wr_data    = cap[3:0];

    // cap[1] & cap[2] segments hold the 24 address bits (addr0…addr3)
    logic [23:0] cpu_addr;
    assign { cpu_addr[6*1 +: 6], cpu_addr[6*0 +: 6] } = cap[23:12];   // {addr1,addr0}
    assign { cpu_addr[6*3 +: 6], cpu_addr[6*2 +: 6] } = cap[35:24];   // {addr3,addr2}

    // phase‑3 handshake comes in directly (only 3 LSBs used)
    logic mem_req_ready  = in_bits[2];
    logic mem_resp_valid = in_bits[1];
    logic mem_resp_data  = in_bits[0];

    // ---------------------------------------------------------------------
    // 4.  Outputs from `top` (21 bits) → 24‑bit parallel word
    // ---------------------------------------------------------------------
    // wires from top
    logic [3:0] cpu_ready, cpu_read_valid, cpu_read_data;
    logic       mem_req_valid, mem_req_rw, mem_req_data;
    logic [5:0] mem_req_addr;

    // pad with 3 zeros (MSBs) for 24 bits total
    logic [23:0] par_out;
    assign par_out = {
        3'b000,                 // padding
        cpu_ready,              // 20:17
        cpu_read_valid,         // 16:13
        cpu_read_data,          // 12:9
        mem_req_valid,          // 8
        mem_req_rw,             // 7
        mem_req_addr,           // 6:1
        mem_req_data            // 0
    };

    // ---------------------------------------------------------------------
    // 5.  Drive the 12‑bit serial output during phases 4 and 5 (no extra regs)
    // ---------------------------------------------------------------------
    assign out_bits = (phase == 3'd4)? par_out[11:0] : par_out[23:12];   // lower half/upper half

    // ---------------------------------------------------------------------
    // 6.  Instantiate the DUT
    // ---------------------------------------------------------------------
    top dut (
        .clk             (top_clk),
        .reset_n         (reset_n),

        // CPU side
        .cpu_valid       (cpu_valid),
        .cpu_command     (cpu_command),
        .cpu_addr        (cpu_addr),
        .cpu_write_data  (cpu_wr_data),
        .cpu_ready       (cpu_ready),
        .cpu_read_valid  (cpu_read_valid),
        .cpu_read_data   (cpu_read_data),

        // Memory side
        .mem_req_valid   (mem_req_valid),
        .mem_req_rw      (mem_req_rw),
        .mem_req_addr    (mem_req_addr),
        .mem_req_data    (mem_req_data),
        .mem_req_ready   (mem_req_ready),
        .mem_resp_valid  (mem_resp_valid),
        .mem_resp_data   (mem_resp_data)
    );

endmodule : wrapper
