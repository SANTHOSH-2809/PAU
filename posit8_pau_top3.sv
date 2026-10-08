`timescale 1ns/1ps

// ============================================================================
// 3-Stage Fully-Pipelined Posit(8,0) Arithmetic Unit (PAU)
// ----------------------------------------------------------------------------
// Target Device: Xilinx Zynq-7000 (ZedBoard: xc7z020clg484-1)
// Target Clock : 100 MHz (Period = 10.000 ns)
//
// Pipeline Architecture:
//   - Stage 1 (Decode) : Unpack operands 'a' and 'b' (regime, exp, frac) -> Q
//   - Stage 2 (Execute): Fixed-point Add / Sub / Multiply -> Numerator & Denominator
//   - Stage 3 (Encode) : Leading-bit search, regime shift & round-to-nearest-even
//
// Performance:
//   - Latency   : 3 clock cycles
//   - Throughput: 1 result per clock cycle (100 Mops/sec @ 100 MHz)
//   - Timing    : Meets 100 MHz with large positive setup slack
// ============================================================================

module posit8_pau_top #(
    parameter int N  = 8,
    parameter int QW = 26
)(
    input  logic         clk,
    input  logic         rst_n,
    input  logic         valid_in,
    input  logic [N-1:0] a,
    input  logic [N-1:0] b,
    input  logic [1:0]   op,
    output logic         valid_out,
    output logic [N-1:0] result
);

    // ========================================================================
    // STAGE 1: Operand Decoding & Registration
    // ========================================================================
    logic                 s1_dec_sign_a;
    logic signed [QW-1:0] s1_dec_qa_comb;
    logic                 s1_dec_zero_a_comb;
    logic                 s1_dec_nar_a_comb;

    logic                 s1_dec_sign_b;
    logic signed [QW-1:0] s1_dec_qb_comb;
    logic                 s1_dec_zero_b_comb;
    logic                 s1_dec_nar_b_comb;

    posit_decoder #(.N(N), .QW(QW)) u_dec_a (
        .posit     (a),
        .sign      (s1_dec_sign_a),
        .q         (s1_dec_qa_comb),
        .zero_flag (s1_dec_zero_a_comb),
        .nar_flag  (s1_dec_nar_a_comb)
    );

    posit_decoder #(.N(N), .QW(QW)) u_dec_b (
        .posit     (b),
        .sign      (s1_dec_sign_b),
        .q         (s1_dec_qb_comb),
        .zero_flag (s1_dec_zero_b_comb),
        .nar_flag  (s1_dec_nar_b_comb)
    );

    // Stage 1 Pipeline Registers
    logic signed [QW-1:0] s1_qa_r, s1_qb_r;
    logic                 s1_zero_a_r, s1_zero_b_r;
    logic                 s1_nar_a_r,  s1_nar_b_r;
    logic [1:0]           s1_op_r;
    logic                 s1_valid_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_qa_r     <= '0;
            s1_qb_r     <= '0;
            s1_zero_a_r <= 1'b0;
            s1_zero_b_r <= 1'b0;
            s1_nar_a_r  <= 1'b0;
            s1_nar_b_r  <= 1'b0;
            s1_op_r     <= 2'b00;
            s1_valid_r  <= 1'b0;
        end else begin
            s1_qa_r     <= s1_dec_qa_comb;
            s1_qb_r     <= s1_dec_qb_comb;
            s1_zero_a_r <= s1_dec_zero_a_comb;
            s1_zero_b_r <= s1_dec_zero_b_comb;
            s1_nar_a_r  <= s1_dec_nar_a_comb;
            s1_nar_b_r  <= s1_dec_nar_b_comb;
            s1_op_r     <= op;
            s1_valid_r  <= valid_in;
        end
    end

    // ========================================================================
    // STAGE 2: Arithmetic Execution & Registration
    // ========================================================================
    logic signed [QW-1:0] s2_num_addsub;
    logic signed [QW-1:0] s2_num_mul;

    logic signed [QW-1:0] s2_final_num_comb;
    logic [7:0]           s2_final_den_comb;
    logic                 s2_final_zero_comb;
    logic                 s2_final_nar_comb;

    posit_addsub #(.QW(QW)) u_addsub (
        .q_a     (s1_qa_r),
        .q_b     (s1_qb_r),
        .sub_sel (s1_op_r == 2'b01),
        .num_r   (s2_num_addsub)
    );

    posit_mul #(.QW(QW)) u_mul (
        .q_a     (s1_qa_r),
        .q_b     (s1_qb_r),
        .num_r   (s2_num_mul)
    );

    always_comb begin
        s2_final_num_comb  = '0;
        s2_final_den_comb  = 8'd1;
        s2_final_zero_comb = 1'b0;
        s2_final_nar_comb  = 1'b0;

        case (s1_op_r)
            2'b00: begin // ADD
                s2_final_num_comb = s2_num_addsub;
                s2_final_den_comb = 8'd1;
            end
            2'b01: begin // SUB
                s2_final_num_comb = s2_num_addsub;
                s2_final_den_comb = 8'd1;
            end
            2'b10: begin // MUL
                s2_final_num_comb = s2_num_mul;
                s2_final_den_comb = 8'd64;
            end
            default: begin
                s2_final_nar_comb = 1'b1;
            end
        endcase

        // NaR has highest priority
        if (s1_nar_a_r || s1_nar_b_r) begin
            s2_final_nar_comb  = 1'b1;
            s2_final_zero_comb = 1'b0;
        end
        else if (s2_final_num_comb == 0) begin
            s2_final_zero_comb = 1'b1;
        end
    end

    // Stage 2 Pipeline Registers
    logic signed [QW-1:0] s2_num_r;
    logic [7:0]           s2_den_r;
    logic                 s2_zero_r;
    logic                 s2_nar_r;
    logic                 s2_valid_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_num_r   <= '0;
            s2_den_r   <= 8'd1;
            s2_zero_r  <= 1'b0;
            s2_nar_r   <= 1'b0;
            s2_valid_r <= 1'b0;
        end else begin
            s2_num_r   <= s2_final_num_comb;
            s2_den_r   <= s2_final_den_comb;
            s2_zero_r  <= s2_final_zero_comb;
            s2_nar_r   <= s2_final_nar_comb;
            s2_valid_r <= s1_valid_r;
        end
    end

    // ========================================================================
    // STAGE 3: Posit Encoding, Rounding & Output Registration
    // ========================================================================
    logic [N-1:0] s3_encoded_bits_comb;

    posit_encoder #(.N(N), .QW(QW)) u_encoder (
        .num       (s2_num_r),
        .den       (s2_den_r),
        .zero_flag (s2_zero_r),
        .nar_flag  (s2_nar_r),
        .bits      (s3_encoded_bits_comb)
    );

    // Stage 3 Output Registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result    <= '0;
            valid_out <= 1'b0;
        end else begin
            result    <= s3_encoded_bits_comb;
            valid_out <= s2_valid_r;
        end
    end

endmodule
