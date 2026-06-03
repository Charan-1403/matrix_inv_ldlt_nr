`timescale 1ns / 1ps

module nr_inversion #(
    parameter DATA_WIDTH = 32  // Bit-width of the input data and datapath
)(
    input  wire                         clk,     // System clock
    input  wire                         rst_n,   // Active-low asynchronous reset
    input  wire                         start,   // Trigger to begin the division calculation
    input  wire signed [DATA_WIDTH-1:0] d_in,    // Denominator input to be inverted
    
    output reg                          done,    // Completion flag
    output reg  signed [DATA_WIDTH-1:0] d_out    // Calculated reciprocal (1 / d_in)
);

    // Explicit Hex for 2.0 in Q16.16 to prevent synthesis truncation
    localparam signed [DATA_WIDTH-1:0] TWO_Q16 = 32'h0002_0000;

    // ------------------------------------------------------------------
    // 1. Leading Zero Counting
    // Determines the magnitude of the input to calculate the shift amount
    // ------------------------------------------------------------------
    reg [4:0] lz_count;
    integer i;
    
    always @(*) begin
        lz_count = 31;
        if (d_in > 0) begin
            for(i = 0; i < DATA_WIDTH; i = i + 1) begin
                if(d_in[i]) lz_count = 5'd31 - i;
            end
        end
    end

    // ------------------------------------------------------------------
    // 2. Input Normalization
    // Shifts the input so the leading 1 is just below the integer bits
    // ------------------------------------------------------------------
    wire shift_dir = (lz_count < 5'd15);
    wire [4:0] shift_amt = shift_dir ? (5'd15 - lz_count) : (lz_count - 5'd15);
    wire signed [DATA_WIDTH-1:0] norm_in = shift_dir ? (d_in >>> shift_amt) : (d_in <<< shift_amt);

    // ------------------------------------------------------------------
    // 3. ROM Lookup (Combinational)
    // Provides the initial guess (x_0) based on the top 4 fraction bits
    // ------------------------------------------------------------------
    reg signed [DATA_WIDTH-1:0] rom_seed;
    
    always @(*) begin
        case (norm_in[15:12])
            4'b0000: rom_seed = 32'd63550;
            4'b0001: rom_seed = 32'd59918;
            4'b0010: rom_seed = 32'd56680;
            4'b0011: rom_seed = 32'd53773;
            4'b0100: rom_seed = 32'd51150;
            4'b0101: rom_seed = 32'd48771;
            4'b0110: rom_seed = 32'd46603;
            4'b0111: rom_seed = 32'd44620;
            4'b1000: rom_seed = 32'd42799;
            4'b1001: rom_seed = 32'd41121;
            4'b1010: rom_seed = 32'd39569;
            4'b1011: rom_seed = 32'd38130;
            4'b1100: rom_seed = 32'd36792;
            4'b1101: rom_seed = 32'd35545;
            4'b1110: rom_seed = 32'd34380;
            4'b1111: rom_seed = 32'd33288;
        endcase
    end

    // ------------------------------------------------------------------
    // 4. Guaranteed 1-Cycle Multiplier Datapath
    // Pipelined multiplier to ensure timing closure on the DSP slices
    // ------------------------------------------------------------------
    reg signed [DATA_WIDTH-1:0] op_a, op_b;
    wire signed [63:0] full_mult = $signed(op_a) * $signed(op_b);
    reg signed [DATA_WIDTH-1:0] trunc_mult;
    
    always@(posedge clk) begin
        if(!rst_n) trunc_mult <= 0;
        else trunc_mult <= full_mult[47:16];
    end

    // ------------------------------------------------------------------
    // 5. Output Denormalization 
    // Reverses the initial shift applied during normalization
    // ------------------------------------------------------------------
    reg signed [DATA_WIDTH-1:0] x_n;
    wire signed [DATA_WIDTH-1:0] denorm_out = shift_dir ? (x_n >>> shift_amt) : (x_n <<< shift_amt);

    // ------------------------------------------------------------------
    // 6. Explicit State Machine
    // Controls the Newton-Raphson iteration sequence: x_{n+1} = x_n * (2 - y * x_n)
    // ------------------------------------------------------------------
    reg [3:0] state;
    reg signed [DATA_WIDTH-1:0] y;

    localparam [3:0]
        IDLE      = 4'd0,
        IT1_M1    = 4'd1,
        IT1_WAIT  = 4'd2,
        IT1_M2    = 4'd3,
        IT1_M2_W  = 4'd4,
        IT2_M1    = 4'd5,
        IT2_WAIT  = 4'd6,
        IT2_M2    = 4'd7,
        IT2_M2_W  = 4'd8,
        FINISH    = 4'd9;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            done  <= 0;
            d_out <= 0;
            op_a  <= 0; 
            op_b  <= 0;
        end else begin
            done <= 0;
            case (state)
                IDLE: begin
                    if (start) begin
                        if (d_in == 0) begin
                            d_out <= 0;
                            done  <= 1;
                        end else begin
                            y     <= norm_in;   // Capture normalized input
                            x_n   <= rom_seed;  // Capture initial guess
                            state <= IT1_M1;
                        end
                    end
                end
                
                // ITERATION 1
                IT1_M1: begin
                    op_a  <= y; 
                    op_b  <= x_n;               // y * x_0
                    state <= IT1_WAIT;
                end
                IT1_WAIT: begin
                    state <= IT1_M2;            // Let multiplier settle
                end
                IT1_M2: begin
                    op_a  <= x_n; 
                    op_b  <= TWO_Q16 - trunc_mult; // x_0 * (2 - y*x_0)
                    state <= IT1_M2_W;
                end
                IT1_M2_W: begin
                    state <= IT2_M1;
                end
                
                // ITERATION 2
                IT2_M1: begin
                    x_n   <= trunc_mult;        // Save x_1
                    op_a  <= y; 
                    op_b  <= trunc_mult;        // y * x_1
                    state <= IT2_WAIT;
                end
                IT2_WAIT: begin
                    state <= IT2_M2;
                end
                IT2_M2: begin
                    op_a  <= x_n; 
                    op_b  <= TWO_Q16 - trunc_mult; // x_1 * (2 - y*x_1)
                    state <= IT2_M2_W;
                end
                IT2_M2_W: begin
                    state <= FINISH;
                end
                
                // OUTPUT
                FINISH: begin
                    x_n   <= trunc_mult;        // Save x_2
                    state <= FINISH + 1;        // Wait 1 cycle for x_n to pass through combinational denorm_out
                end
                FINISH + 1: begin
                    d_out <= denorm_out;
                    done  <= 1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule
