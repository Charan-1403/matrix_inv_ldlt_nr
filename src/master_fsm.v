module master_fsm #(parameter N = 7, parameter ADDR_WIDTH = 7, parameter DATA_WIDTH = 32) (
    input wire clk, rst_n,
    input wire start, nr_done,
    output reg nr_start,
    output reg L_wr_en, U_wr_en, D_wr_en, A_wr_en,
    input wire L1_rd_val, L2_rd_val, D_rd_val, A_rd_val, U1_rd_val, U2_rd_val, Dinv_rd_val,
    input wire signed[DATA_WIDTH-1:0] A, L1, L2, U1, U2, D, Dinv,
    output reg [ADDR_WIDTH-1:0] A_rd_addr, L1_rd_addr, L2_rd_addr, U1_rd_addr, U2_rd_addr, D_rd_addr, Dinv_rd_addr,
    output reg [ADDR_WIDTH-1:0] L_wr_addr, U_wr_addr, D_wr_addr, A_wr_addr,
    output reg signed [DATA_WIDTH-1:0] L_wr_data, U_wr_data, D_wr_data, A_wr_data,
    output reg done
);
    
    wire[ADDR_WIDTH-1:0] addr_1_r, addr_2_r, addr_3_r, addr_w;
    wire[63:0] intmd_mult_result;
    
    reg nr_done_sticky;
    
    reg[7:0] i,j,k;
    reg[1:0] phase;
    reg signed[DATA_WIDTH-1:0] op1, op2, op3;
    wire signed[DATA_WIDTH-1:0] result;
    
    always@(*) begin
        if(!rst_n) begin
            op1 = 0;
            op2 = 0;
            op3 = 0;
        end
        else begin
            case(phase)
                2'b00: begin
                    op1 = L1;
                    op2 = L2;
                    op3 = D;
                end
                
                2'b01: begin
                    op1 = L1;
                    op2 = U1;
                    op3 = -32'd65536;
                end
                
                2'b10: begin
                    op1 = U1;
                    op2 = U2;
                    op3 = Dinv;
                end
                
                default: begin
                    op1 = 0;
                    op2 = 0;
                    op3 = 0;
                end
            endcase
        end
    end
    
    
always@(*) begin
        // 1. ALL defaults must be set here to prevent 'X' latches!
        L1_rd_addr = 0; L2_rd_addr = 0; D_rd_addr = 0; D_wr_addr = 0;
        A_rd_addr = 0; U1_rd_addr = 0; U2_rd_addr = 0; L_wr_addr = 0;
        U_wr_addr = 0; A_wr_addr = 0;
        
        // ---> YOU WERE MISSING THIS DEFAULT <---
        Dinv_rd_addr = 0; 
        
        if(phase == 0) begin
            L1_rd_addr   = addr_1_r;
            L2_rd_addr   = addr_2_r;
            D_rd_addr    = addr_3_r;
            D_wr_addr    = addr_w;
            
            // ---> YOU WERE MISSING THESE THREE <---
            A_rd_addr    = addr_w;       
            L_wr_addr    = addr_w;       
            Dinv_rd_addr = (j * N) + j;  
        end
        else if(phase == 1) begin
            U_wr_addr  = addr_w;
            L1_rd_addr = addr_1_r;
            U1_rd_addr = addr_2_r;
        end
        else if(phase == 2) begin
            if(state == MIRROR_WRITE) A_wr_addr = (j * N) + i;
            else A_wr_addr = addr_w;
            U1_rd_addr   = addr_1_r;
            U2_rd_addr   = addr_2_r;
            Dinv_rd_addr = addr_3_r;
        end
    end
    
    address_gen #(.N(N)) agu (.clk(clk),
                     .rst_n(rst_n),
                     .i(i),
                     .j(j),
                     .k(k),
                     .phase(phase),
                     .addr_1_r(addr_1_r),
                     .addr_2_r(addr_2_r),
                     .addr_3_r(addr_3_r),
                     .addr_w(addr_w));    
                     
    dsp_cascade dsp (.clk(clk),
                     .rst_n(rst_n),
                     .op1(op1),
                     .op2(op2),
                     .op3(op3),
                     .result(result));

    localparam IDLE      = 4'd0;
    localparam COMPUTE   = 4'd1;
    localparam DRAIN     = 4'd2;
    localparam NEXT_ELEM = 4'd3;
    localparam WRITEBACK_PREP = 4'd4;
    localparam WRITEBACK_EXEC = 4'd5;
    localparam DONE_ST   = 4'd6;
    localparam NR_SYNC = 4'd7;
    localparam MIRROR_WRITE = 4'd8;

    reg [3:0] state;
    reg [2:0] drain_cnt;
    reg signed [DATA_WIDTH-1:0] diff_reg, accum_reg;
    reg [4:0] accum_sig_pipeline;
    reg k_done;
    wire accum_valid = (state == COMPUTE) && (!k_done);
    always @(*) begin
        case(phase)
            // Phase 0 (LDL^T): k goes from 0 to j-1
            2'd0: k_done = (k >= j); 
            // Phase 1 (M = L^-1): k goes from j to i-1
            2'd1: k_done = (k >= i); 
            // Phase 2 (A^-1): k goes from i to N-1
            2'd2: k_done = (k >= N); 
            default: k_done = 1'b1;
        endcase
    end
    
    always@(posedge clk) begin
        if(!rst_n) nr_done_sticky <= 0;
        else begin
            if(nr_done) nr_done_sticky <= 1'b1;
            else if(state == NEXT_ELEM && i == N - 1) nr_done_sticky <= 1'b0;
            else if(state == IDLE) nr_done_sticky <= 1'b0;
        end
    end
    
    always@(posedge clk) begin
        if(!rst_n) accum_sig_pipeline <= 5'b0;
        else begin
            accum_sig_pipeline <= {accum_valid, accum_sig_pipeline[4:1]};
        end
    end
    
    always@(posedge clk) begin
        if(!rst_n) accum_reg <= 0;
        else begin
            if(state == NEXT_ELEM || state == IDLE) accum_reg <= 0;
            else if(accum_sig_pipeline[0]) accum_reg <= accum_reg + result;
            
        end
    end
    

    always @(posedge clk) begin
        if (!rst_n) begin
            state     <= IDLE;
            phase     <= 2'd0;
            i         <= 0;
            j         <= 0;
            k         <= 0;
            drain_cnt <= 0;
            done      <= 0;
        end else begin
            D_wr_en <= 0;
            A_wr_en <= 0;
            U_wr_en <= 0;
            L_wr_en <= 0;
            
            
            case(state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        phase <= 2'd0;
                        j     <= 0;
                        i     <= 0; // i starts at j (diagonal)
                        k     <= 0; // Phase 0 always starts k at 0
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Iterate k for the MAC loop
                    if (!k_done) begin
                        k <= k + 1;
                    end else begin
                        // Once MAC iterations are complete, flush the pipeline
                        state     <= DRAIN;
                        drain_cnt <= 0;
                    end
                end
                
                DRAIN: begin
                    // Wait 2 clock cycles for the 2-stage DSP cascade to finish
                    if (drain_cnt == 3'd5) begin
                        if(phase == 2'b00 && i > j)state <= NR_SYNC;
                        else state <= WRITEBACK_PREP;
                        // Here is where you will eventually pulse your write enables (L_wr_en, etc)
                    end else begin
                        drain_cnt <= drain_cnt + 1;
                    end
                end
                
                NR_SYNC: begin
                    if(nr_done_sticky) state <= WRITEBACK_PREP;
                end
                
                WRITEBACK_PREP: begin
                    diff_reg <= A - accum_reg;
                    state <= WRITEBACK_EXEC;
                end
                
                WRITEBACK_EXEC: begin
                    case(phase)
                        2'b00: begin
                            if(i == j) begin
                                D_wr_en <= 1;
                                D_wr_data <= diff_reg;
                                nr_start <= 1;
                            end
                            else begin
                                L_wr_en <= 1;
                                L_wr_data <=  intmd_mult_result[47:16];   
                            end
                        end
                        
                        2'b01: begin
                            U_wr_en <= 1;
                            U_wr_data <= accum_reg;
                        end
                        
                        2'b10: begin
                            A_wr_en <= 1; 
                            A_wr_data <= accum_reg;
                        end
                    endcase
                    if (phase == 2'd2 && i == j)state <= NEXT_ELEM;
                    else state <= MIRROR_WRITE;
                   // if (U_wr_en) $display("  [DEBUG] Writing to U_RAM at Addr: %d", U_wr_addr);
                end
                
                MIRROR_WRITE: begin
                    A_wr_en <= 1'b1;
                     // Mirror the coordinates
                    A_wr_data <= accum_reg;
                    state <= NEXT_ELEM; // Then proceed to the next element
                end
                
                NEXT_ELEM: begin
                    nr_start <= 0;
                    
                    // 1. Advance the Row (i)
                    if (i < N - 1) begin
                        i <= i + 1;
                        if      (phase == 2'd0) k <= 0;
                        else if (phase == 2'd1) k <= j;
                        else if (phase == 2'd2) k <= i + 1; 
                        state <= COMPUTE;
                    end 
                    
                    // 2. Advance the Column (j)
                    else if (j < (phase == 2'd1 ? N - 2 : N - 1)) begin
                        j <= j + 1;
                        
                        // ---> CORRECTED BOUNDARY GUARDS <---
                        if (phase == 2'd1) begin
                            if (j + 2 < N) i <= j + 2; 
                            else           i <= N - 1; // Clamp!
                        end else begin
                            if (j + 1 < N) i <= j + 1;
                            else           i <= N - 1; // Clamp!
                        end
                        
                        if      (phase == 2'd0) k <= 0;
                        else if (phase == 2'd1) k <= j + 1; 
                        else if (phase == 2'd2) k <= j + 1; 
                        state <= COMPUTE;
                    end 
                    
                    // 3. Advance the Phase
                    else begin
                        if (phase == 2'd0) begin
                            phase <= 2'd1; j <= 0; i <= 1; k <= 0; state <= COMPUTE;
                        end else if (phase == 2'd1) begin
                            phase <= 2'd2; j <= 0; i <= 0; k <= 0; state <= COMPUTE;
                        end else begin
                            state <= DONE_ST;
                        end
                    end
                end
                
                DONE_ST: begin
                    done <= 1'b1;
                    // Wait for start to go low to return to IDLE, or return immediately
                    if (!start) state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    assign intmd_mult_result = ($signed(diff_reg) * $signed(Dinv));
    
endmodule
