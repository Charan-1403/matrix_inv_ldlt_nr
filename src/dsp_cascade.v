`timescale 1ns / 1ps

module dsp_cascade#(parameter DATA_WIDTH = 32)(
        input clk, rst_n,
        input wire signed[DATA_WIDTH-1:0] op1,
        input wire signed[DATA_WIDTH-1:0] op2,
        input wire signed[DATA_WIDTH-1:0] op3,
        output reg signed[DATA_WIDTH-1:0] result
    );
    
    reg signed[DATA_WIDTH-1:0] intmd_result, reg_op3, reg_op3_2;
    wire signed[DATA_WIDTH*2-1:0] intmd_result_wire, result_wire;
    
    always@(posedge clk) reg_op3 <= op3;
    always@(posedge clk) reg_op3_2 <= reg_op3;
    always@(posedge clk) intmd_result <= intmd_result_wire[47:16];
    always@(posedge clk) result <= result_wire[47:16];
    
    mac_unit m0 (.clk(clk),
                 .rst_n(rst_n),
                 .a(op1),
                 .b(op2),
                 .mult_result(intmd_result_wire));

    mac_unit m1 (.clk(clk),
                 .rst_n(rst_n),
                 .a(intmd_result),
                 .b(reg_op3_2),
                 .mult_result(result_wire));
    
endmodule
