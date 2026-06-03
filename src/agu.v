module address_gen #(parameter DATA_WIDTH = 32, parameter ADDR_WIDTH = 8, parameter N = 7) (
    input clk, rst_n,
    input wire[7:0] i, j, k,
    input wire[1:0] phase,
    output reg[ADDR_WIDTH-1:0] addr_1_r, addr_2_r, addr_3_r, addr_w
);
    
    always@(*) begin
        if(!rst_n) begin
            addr_1_r = 0;
            addr_2_r = 0;
            addr_3_r = 0;
            addr_w = 0;
        end
        else begin
            case(phase)
                2'b00: begin
                    addr_1_r = (i * N) + k;
                    addr_2_r = (j * N) + k;
                    addr_3_r = (k * N) + k;
                    addr_w = (i * N) + j;
                end
                2'b01: begin
                    addr_1_r = (i * N) + k;
                    addr_2_r = (k * N) + j;
                    addr_3_r = 0;
                    addr_w = (i * N) + j;
                end
                2'b10: begin
                    addr_1_r = (k * N) + i;
                    addr_2_r = (k * N) + j;
                    addr_3_r = (k * N) + k;
                    addr_w = (i * N) + j;
                end
                default: begin
                    addr_1_r = 0;
                    addr_2_r = 0;
                    addr_3_r = 0;
                    addr_w = 0;
                end
            endcase
        end
    end

endmodule