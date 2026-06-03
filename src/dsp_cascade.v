`timescale 1ns / 1ps

// Module: dsp_cascade
module dsp_cascade #(
    parameter DATA_WIDTH = 32  // Bit-width of operands (Q16.16 fixed-point format)
)(
        input  wire                         clk,    // System clock
        input  wire                         rst_n,  // Active-low reset
        input  wire signed [DATA_WIDTH-1:0] op1,    // First operand (A)
        input  wire signed [DATA_WIDTH-1:0] op2,    // Second operand (B)
        input  wire signed [DATA_WIDTH-1:0] op3,    // Third operand (C, delayed and multiplied by A*B)
        
        output reg  signed [DATA_WIDTH-1:0] result  // Final truncated product: (op1 * op2) * op3
    );
    
    // Internal Pipeline Registers and Wires
    reg  signed [DATA_WIDTH-1:0]   intmd_result, reg_op3, reg_op3_2; // Pipeline delay registers
    wire signed [DATA_WIDTH*2-1:0] intmd_result_wire, result_wire;   // Full 64-bit raw multiplication outputs
    
    
    // Pipeline Synchronization & Fixed-Point Truncation
    always@(posedge clk) reg_op3      <= op3;
    always@(posedge clk) reg_op3_2    <= reg_op3;
    always@(posedge clk) intmd_result <= intmd_result_wire[47:16];
    always@(posedge clk) result       <= result_wire[47:16];
    
    // Instantiation #1: Stage 1 Multiplier (op1 * op2)
    mac_unit m0 (
        .clk(clk),
        .rst_n(rst_n),
        .a(op1),
        .b(op2),
        .mult_result(intmd_result_wire) // 64-bit untruncated product
    );

    // Instantiation #2: Stage 2 Multiplier (intmd_result * delayed op3)
    mac_unit m1 (
        .clk(clk),
        .rst_n(rst_n),
        .a(intmd_result),
        .b(reg_op3_2),
        .mult_result(result_wire)       // 64-bit untruncated final product
    );
    
endmodule
