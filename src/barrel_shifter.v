`timescale 1ns / 1ps
module barrel_shifter #(parameter DATA_WIDTH = 32)(
        input wire signed[DATA_WIDTH-1:0] in,
        input wire[$clog2(DATA_WIDTH)-1:0] shamt,
        input wire r_l_shift,
        output wire signed[DATA_WIDTH-1:0] out
    );
    
    assign out = r_l_shift ? (in >>> shamt) : (in << shamt);
    
endmodule
