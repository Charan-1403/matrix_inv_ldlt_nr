`timescale 1ns / 1ps

// Module: address_gen

module address_gen #(
    parameter DATA_WIDTH = 32, // Bit-width of matrix elements (unused here, kept for consistency)
    parameter ADDR_WIDTH = 8,  // Bit-width of the generated memory addresses
    parameter N          = 7   // Dimension of the square matrix (N x N)
) (
    input  wire                  clk,      // System clock (present but unused in combinational logic)
    input  wire                  rst_n,    // Active-low reset signal
    input  wire [7:0]            i, j, k,  // Loop iteration counters (row, column, dot-product)
    input  wire [1:0]            phase,    // Current FSM execution phase (0, 1, or 2)
    
    output reg  [ADDR_WIDTH-1:0] addr_1_r, // Read address pointer 1 (Operand A)
    output reg  [ADDR_WIDTH-1:0] addr_2_r, // Read address pointer 2 (Operand B)
    output reg  [ADDR_WIDTH-1:0] addr_3_r, // Read address pointer 3 (Operand C)
    output reg  [ADDR_WIDTH-1:0] addr_w    // Write address pointer (Result Destination)
);
    
    // Combinational Address Routing Logic

    always@(*) begin
        if(!rst_n) begin
            // Reset condition: Safely zero out all memory pointers
            addr_1_r = 0;
            addr_2_r = 0;
            addr_3_r = 0;
            addr_w   = 0;
        end
        else begin
            case(phase)
                // Phase 0: LDL^T Decomposition (Calculating L and D matrices)
                2'b00: begin
                    addr_1_r = (i * N) + k; // Read L[i,k]
                    addr_2_r = (j * N) + k; // Read L[j,k]
                    addr_3_r = (k * N) + k; // Read D[k,k]
                    addr_w   = (i * N) + j; // Write to D[i,j] or L[i,j]
                end
                
                // Phase 1: Forward Substitution (Calculating U matrix)
                2'b01: begin
                    addr_1_r = (i * N) + k; // Read L[i,k]
                    addr_2_r = (k * N) + j; // Read U[k,j]
                    addr_3_r = 0;           // Unused in Phase 1
                    addr_w   = (i * N) + j; // Write to U[i,j]
                end
                
                // Phase 2: Final Inverse Computation (Matrix Multiplication)
                2'b10: begin
                    addr_1_r = (k * N) + i; // Read U[k,i]
                    addr_2_r = (k * N) + j; // Read U[k,j]
                    addr_3_r = (k * N) + k; // Read Dinv[k,k]
                    addr_w   = (i * N) + j; // Write to Final Inverse A[i,j]
                end
                
                // Default Fallback: Ensures robust synthesis and prevents latches
                default: begin
                    addr_1_r = 0;
                    addr_2_r = 0;
                    addr_3_r = 0;
                    addr_w   = 0;
                end
            endcase
        end
    end

endmodule
