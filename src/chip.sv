`default_nettype none

module my_chip (
    input logic [11:0] io_in, // Inputs to your chip
    output logic [11:0] io_out, // Outputs from your chip
    input logic clock,
    input logic reset // Important: Reset is ACTIVE-HIGH
);
    
    wrapper u_wrapper (
        .clk      (clock),
        .reset_n  (~reset),   // convert active-HIGH to active-LOW
        .in_bits  (io_in),
        .out_bits (io_out)
    );
    
endmodule
