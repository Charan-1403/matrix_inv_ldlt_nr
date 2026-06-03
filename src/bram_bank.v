`timescale 1ns / 1ps

// Module: bram_bank

module bram_bank #(
    parameter DATA_WIDTH = 32, // Bit-width of each stored memory word
    parameter ADDR_WIDTH = 12  // Bit-width of the address bus (Depth = 2^ADDR_WIDTH)
)(
    input  wire                  clk,    // System clock signal
    input  wire                  we,     // Write enable flag (active high)
    
    input  wire [ADDR_WIDTH-1:0] addr_a, // Read address pointer for Port A
    input  wire [ADDR_WIDTH-1:0] addr_b, // Read address pointer for Port B
    input  wire [ADDR_WIDTH-1:0] addr_w, // Write address pointer for input data
    
    input  wire [DATA_WIDTH-1:0] din,    // Input data to be written into memory
    
    output reg  [DATA_WIDTH-1:0] dout_a, // Output read data from Port A
    output reg  [DATA_WIDTH-1:0] dout_b  // Output read data from Port B
);
    

    // Memory Array Declaration

    reg [DATA_WIDTH-1:0] mem [0:(2**ADDR_WIDTH)-1];

    // Synchronous Read/Write Logic

    always @(posedge clk) begin
        // Write Operation
        if (we) begin
            mem[addr_w] <= din;
        end
        
        // Read Operations (Port A and Port B)
        dout_a <= mem[addr_a];
        dout_b <= mem[addr_b];
    end

endmodule
