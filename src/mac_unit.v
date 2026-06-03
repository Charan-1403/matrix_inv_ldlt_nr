`timescale 1ns / 1ps

// Module: mac_unit
module mac_unit #(
    parameter DATA_WIDTH = 32  // Bit-width of the input operands
)(
    input  wire                              clk,         // System clock signal
    input  wire                              rst_n,       // Active-low asynchronous reset
    input  wire signed [DATA_WIDTH-1:0]      a,           // Multiplicand A
    input  wire signed [DATA_WIDTH-1:0]      b,           // Multiplier B
    
    output reg  signed [(DATA_WIDTH*2)-1:0]  mult_result  // Full-precision registered product
);

    // Synchronous Multiplication Logic

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset condition: Clear the output register
            mult_result  <= 64'd0;
        end else begin
            // Perform signed multiplication
            mult_result <= $signed(a) * $signed(b);
        end
    end
    
endmodule
