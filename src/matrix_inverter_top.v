`timescale 1ns / 1ps

module matrix_inverter_top #(
    parameter N          = 7,  // Dimension of the square matrix (N x N)
    parameter ADDR_WIDTH = 7,  // Bit-width for BRAM addressing
    parameter DATA_WIDTH = 32  // Bit-width of matrix elements (Q16.16)
)(
    input  wire                  clk,             // System clock signal
    input  wire                  rst_n,           // Active-low asynchronous reset
    input  wire                  start,           // Trigger to begin inversion process
    output wire                  done,            // Final completion flag sent to host

    // External Interface to load Matrix A (and U diagonals)
    input  wire                  host_we,         // Host write-enable flag
    input  wire [1:0]            host_target_ram, // 00: A_RAM, 01: U_RAM (to init diagonals)
    input  wire [ADDR_WIDTH-1:0] host_addr,       // Host target memory address
    input  wire [DATA_WIDTH-1:0] host_data,       // Host write data

    // External Interface to read Final Inverse Matrix
    input  wire [ADDR_WIDTH-1:0] host_Out_addr,   // Host read address for final matrix
    output wire [DATA_WIDTH-1:0] host_Out_data    // Host read data (computed inverse)
);

    // Internal Wires & Registers
    wire                         fsm_A_wr_en, fsm_L_wr_en, fsm_U_wr_en, fsm_D_wr_en;
    wire [ADDR_WIDTH-1:0]        fsm_A_wr_addr, fsm_L_wr_addr, fsm_U_wr_addr, fsm_D_wr_addr;
    wire signed [DATA_WIDTH-1:0] fsm_A_wr_data, fsm_L_wr_data, fsm_U_wr_data, fsm_D_wr_data;
    
    wire [ADDR_WIDTH-1:0]        A_rd_addr, L1_rd_addr, L2_rd_addr, U1_rd_addr, U2_rd_addr, D_rd_addr, Dinv_rd_addr;
    wire signed [DATA_WIDTH-1:0] A_data, L1_data, L2_data, U1_data, U2_data, D_data, Dinv_data;

    wire                         nr_start, nr_done_wire;
    wire signed [DATA_WIDTH-1:0] nr_dout_wire;
    
    // Glue logic to remember WHERE to write the NR result
    reg [ADDR_WIDTH-1:0] nr_addr_latch;
    always @(posedge clk) begin
        if (!rst_n) begin
            nr_addr_latch <= 0;
        end else if (nr_start) begin
            nr_addr_latch <= fsm_D_wr_addr;
        end
    end

    // Holds the memory multiplexers open for the FSM until 'done' is asserted
    reg busy;
    always @(posedge clk) begin
        if (!rst_n) busy <= 1'b0;
        else if (start) busy <= 1'b1;
        else if (done) busy <= 1'b0;
    end

    // Memory Instantiations (BRAM Banks)
    
    // A_BRAM (Multiplexed: Host writes, FSM computes, Host reads)
    bram_bank #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) A_BRAM (
        .clk(clk), 
        .we(busy ? fsm_A_wr_en : (host_we && host_target_ram == 2'b00)), 
        .addr_w(busy ? fsm_A_wr_addr : host_addr), 
        .din(busy ? fsm_A_wr_data : host_data),
        
        .addr_a(A_rd_addr),     .dout_a(A_data), 
        .addr_b(host_Out_addr), .dout_b(host_Out_data)
    );

    // L_BRAM
    bram_bank #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) L_BRAM (
        .clk(clk), 
        .we(fsm_L_wr_en),       .addr_w(fsm_L_wr_addr), .din(fsm_L_wr_data),
        .addr_a(L1_rd_addr),    .dout_a(L1_data), 
        .addr_b(L2_rd_addr),    .dout_b(L2_data) 
    );

    // U_BRAM (Multiplexed: Host initializes diagonals to 1.0)
    bram_bank #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) U_BRAM (
        .clk(clk), 
        .we(busy ? fsm_U_wr_en : (host_we && host_target_ram == 2'b01)), 
        .addr_w(busy ? fsm_U_wr_addr : host_addr), 
        .din(busy ? fsm_U_wr_data : host_data),
        
        .addr_a(U1_rd_addr),    .dout_a(U1_data), 
        .addr_b(U2_rd_addr),    .dout_b(U2_data) 
    );

    // D_BRAM
    bram_bank #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) D_BRAM (
        .clk(clk), 
        .we(fsm_D_wr_en),       .addr_w(fsm_D_wr_addr), .din(fsm_D_wr_data),
        .addr_a(D_rd_addr),     .dout_a(D_data), 
        .addr_b(7'b0),          .dout_b() 
    );

    // Dinv_BRAM
    bram_bank #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) Dinv_BRAM (
        .clk(clk), 
        .we(nr_done_wire),      .addr_w(nr_addr_latch), .din(nr_dout_wire),
        .addr_a(Dinv_rd_addr),  .dout_a(Dinv_data), 
        .addr_b(7'b0),          .dout_b() 
    );

    // Newton-Raphson Inversion Core
    nr_inversion #(.DATA_WIDTH(DATA_WIDTH)) nr_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(nr_start),
        .d_in(fsm_D_wr_data),
        .done(nr_done_wire),
        .d_out(nr_dout_wire)
    );

    // Master FSM & AGU
    master_fsm #(.N(N), .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) fsm_inst (
        .clk(clk), 
        .rst_n(rst_n), 
        .start(start),
        
        .nr_start(nr_start), 
        .nr_done(nr_done_wire),
        .done(done),
        
        .L_wr_en(fsm_L_wr_en),     .U_wr_en(fsm_U_wr_en), 
        .D_wr_en(fsm_D_wr_en),     .A_wr_en(fsm_A_wr_en),
        
        .L1_rd_val(1'b1),          .L2_rd_val(1'b1),        .D_rd_val(1'b1), .A_rd_val(1'b1), 
        .U1_rd_val(1'b1),          .U2_rd_val(1'b1),        .Dinv_rd_val(1'b1),
        
        .A(A_data),                .L1(L1_data),            .L2(L2_data), 
        .U1(U1_data),              .U2(U2_data),            .D(D_data),      .Dinv(Dinv_data),
        
        .A_rd_addr(A_rd_addr),     .L1_rd_addr(L1_rd_addr), .L2_rd_addr(L2_rd_addr), 
        .U1_rd_addr(U1_rd_addr),   .U2_rd_addr(U2_rd_addr), .D_rd_addr(D_rd_addr),   .Dinv_rd_addr(Dinv_rd_addr),
        
        .L_wr_addr(fsm_L_wr_addr), .U_wr_addr(fsm_U_wr_addr), 
        .D_wr_addr(fsm_D_wr_addr), .A_wr_addr(fsm_A_wr_addr),
        
        .L_wr_data(fsm_L_wr_data), .U_wr_data(fsm_U_wr_data), 
        .D_wr_data(fsm_D_wr_data), .A_wr_data(fsm_A_wr_data)
    );

endmodule
