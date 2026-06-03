module mac_unit_nr #(parameter DATA_WIDTH = 32)(
    input wire clk, 
    input wire rst_n,
    input wire signed [DATA_WIDTH-1:0] a,
    input wire signed [DATA_WIDTH-1:0] b,
    output reg signed [DATA_WIDTH-1:0] mult_result
);
    reg signed [63:0] product_full;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product_full <= 64'd0;
            mult_result  <= 32'd0;
        end else begin
            product_full <= $signed(a) * $signed(b);
            // Extract Q16.16 from the 64-bit product
            mult_result  <= product_full[47:16]; 
        end
    end
endmodule