// -----------------------------------------------------------------------------
// 7-phase serial wrapper (12-bit I/O) for `top`
// -----------------------------------------------------------------------------
module wrapper (
    input  logic        clk,        // fast system clock
    input  logic        reset_n,    // async-low reset
    input  logic [11:0] in_bits,    // serial input  (12 bits)
    output logic [11:0] out_bits    // serial output (12 bits)
);

    // ---------------------------------------------------------------------
    // 1.  ÷7 clock generator for the DUT
    // ---------------------------------------------------------------------
    logic [2:0] phase;                    // 0--6
    always_ff @(posedge clk or negedge reset_n)
        if (!reset_n) phase <= 3'd0;
        else          phase <= (phase == 3'd6) ? 3'd0 : phase + 3'd1;

    // low  : 0-3 (input)   high : 4-6 (run+output)
    logic top_clk = (phase >= 3'd4);

    // ---------------------------------------------------------------------
    // 2.  Four 12-bit capture registers (48 bits total)
    // ---------------------------------------------------------------------
    logic [11:0] cap[3:0];                // cap[0]=cycle0 … cap[3]=cycle3

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            cap[0] <= '0; cap[1] <= '0; cap[2] <= '0; cap[3] <= '0;
        end
        else case (phase)
            3'd0: cap[0] <= in_bits;   // cpu_valid|cmd|wr_data
            3'd1: cap[1] <= in_bits;   // addr0, addr1
            3'd2: cap[2] <= in_bits;   // addr2, addr3
            3'd3: cap[3] <= in_bits;   // mem_req_ready, mem_resp_* (lsb)
            default: ;                 // nothing to capture
        endcase
    end

    // ---------------------------------------------------------------------
    // 3.  Decode the 39 useful input bits for `top`
    // ---------------------------------------------------------------------
    // cap[0] = {cpu_valid[3:0], cpu_cmd[3:0], cpu_wr_data[3:0]}
    logic [3:0] cpu_valid      = cap[0][11:8];
    logic [3:0] cpu_command    = cap[0][7:4];
    logic [3:0] cpu_wr_data    = cap[0][3:0];

    // cap[1] & cap[2] hold the 24 address bits (addr0…addr3)
    logic [3:0][5:0] cpu_addr;
    assign { cpu_addr[1], cpu_addr[0] } = cap[1];   // {addr1,addr0}
    assign { cpu_addr[3], cpu_addr[2] } = cap[2];   // {addr3,addr2}

    // cap[3] lsb = memory handshake
    logic mem_req_ready  = cap[3][2];
    logic mem_resp_valid = cap[3][1];
    logic mem_resp_data  = cap[3][0];

    // ---------------------------------------------------------------------
    // 4.  Outputs from `top` (21 bits) → 24-bit shift register
    // ---------------------------------------------------------------------
    logic [23:0] out_shift;

    // wires from top
    logic [3:0] cpu_ready, cpu_read_valid, cpu_read_data;
    logic       mem_req_valid, mem_req_rw, mem_req_data;
    logic [5:0] mem_req_addr;

    // pack with 3 pad zeros (MSBs) so we have exactly 24 bits
    logic [23:0] par_out = {
        3'b000,                 // padding
        cpu_ready,              // 20:17
        cpu_read_valid,         // 16:13
        cpu_read_data,          // 12:9
        mem_req_valid,          // 8
        mem_req_rw,             // 7
        mem_req_addr,           // 6:1
        mem_req_data            // 0
    };

    // latch straight after the rising edge (phase 4)
    always_ff @(posedge clk or negedge reset_n)
        if (!reset_n) out_shift <= '0;
        else if (phase == 3'd4) out_shift <= par_out;

    // ---------------------------------------------------------------------
    // 5.  Drive the 12-bit serial output during phases 5 and 6
    // ---------------------------------------------------------------------
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) out_bits <= 12'h000;
        else case (phase)
            3'd5: out_bits <= out_shift[11:0];        // lower half
            3'd6: out_bits <= out_shift[23:12];       // upper half
            default: out_bits <= 12'h000;             // idle / tri-state
        endcase
    end

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
