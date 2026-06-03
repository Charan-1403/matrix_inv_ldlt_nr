`timescale 1ns / 1ps

module bram_bank #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 12
)(
    input  wire                  clk,
    input  wire                  we,
    input  wire [ADDR_WIDTH-1:0] addr_a,
    input  wire [ADDR_WIDTH-1:0] addr_b,
    input  wire [ADDR_WIDTH-1:0] addr_w,
    input  wire [DATA_WIDTH-1:0] din,
    output reg  [DATA_WIDTH-1:0] dout_a,
    output reg  [DATA_WIDTH-1:0] dout_b
);
    reg [DATA_WIDTH-1:0] mem [0:(2**ADDR_WIDTH)-1];

    always @(posedge clk) begin
        if (we)
            mem[addr_w] <= din;
        dout_a <= mem[addr_a];
        dout_b <= mem[addr_b];
    end

endmodule