`timescale 1ns/1ps

// ============================================================================
// Posit(8,0) Arithmetic Unit - verified baseline (QW=26)
// ----------------------------------------------------------------------------
// Operations:
//   00 : ADD
//   01 : SUB
//   10 : MUL
//   11 : reserved -> NaR
//
// IMPORTANT:
// This project version intentionally targets the classic/legacy Posit(8,0):
//   N    = 8
//   es   = 0
//   useed = 2
//   minPos = 2^-6 = 1/64
//   maxPos = 2^6  = 64
//
// Correctness strategy:
//   1. Decode every Posit(8,0) exactly into integer Q units where
//          value = Q / 64
//   2. Perform ADD/SUB exactly in Q units.
//   3. Perform MUL exactly as (Qa*Qb)/64 using an exact rational numerator.
//   4. Encode the exact result with round-to-nearest-even (RNE).
//
// This avoids the dynamic part-select/guard-position issues in the previous
// implementation and gives a clean functional baseline for exhaustive
// verification before architectural LUT optimization.
// ============================================================================

module posit8_pau #(
    parameter int N = 8
)(
    input  logic [N-1:0] a,
    input  logic [N-1:0] b,
    input  logic [1:0]   op,
    output logic [N-1:0] result
);

    localparam int QW = 26;

    logic signed [QW-1:0] q_a, q_b;
    logic zero_a, zero_b, nar_a, nar_b;
    logic sign_a, sign_b;

    logic signed [QW-1:0] num_addsub;
    logic signed [QW-1:0] num_mul;

    logic signed [QW-1:0] final_num;
    logic [7:0]            final_den;
    logic                  final_zero;
    logic                  final_nar;

    posit_decoder #(.N(N), .QW(QW)) u_dec_a (
        .posit     (a),
        .sign      (sign_a),
        .q         (q_a),
        .zero_flag (zero_a),
        .nar_flag  (nar_a)
    );

    posit_decoder #(.N(N), .QW(QW)) u_dec_b (
        .posit     (b),
        .sign      (sign_b),
        .q         (q_b),
        .zero_flag (zero_b),
        .nar_flag  (nar_b)
    );

    posit_addsub #(.QW(QW)) u_addsub (
        .q_a      (q_a),
        .q_b      (q_b),
        .sub_sel  (op == 2'b01),
        .num_r    (num_addsub)
    );

    posit_mul #(.QW(QW)) u_mul (
        .q_a      (q_a),
        .q_b      (q_b),
        .num_r    (num_mul)
    );

    always_comb begin
        final_num  = '0;
        final_den  = 8'd1;
        final_zero = 1'b0;
        final_nar  = 1'b0;

        case (op)
            2'b00: begin
                final_num  = num_addsub;
                final_den  = 8'd1;
            end

            2'b01: begin
                final_num  = num_addsub;
                final_den  = 8'd1;
            end

            2'b10: begin
                final_num  = num_mul;
                final_den  = 8'd64;
            end

            default: begin
                final_nar = 1'b1;
            end
        endcase

        // NaR has highest priority.
        if (nar_a || nar_b) begin
            final_nar = 1'b1;
            final_zero = 1'b0;
        end
        else if (final_num == 0) begin
            final_zero = 1'b1;
        end
    end

    posit_encoder #(.N(N), .QW(QW)) u_encoder (
        .num        (final_num),
        .den        (final_den),
        .zero_flag  (final_zero),
        .nar_flag   (final_nar),
        .bits       (result)
    );

endmodule


// ============================================================================
// Exact decoder for Posit(N,0)
// ----------------------------------------------------------------------------
// Internal representation:
//      q = value * 64
//
// For Posit(8,0), every representable finite value is exactly an integer
// multiple of 1/64, so this representation is exact.
// ============================================================================

module posit_decoder #(
    parameter int N  = 8,
    parameter int QW = 26
)(
    input  logic [N-1:0] posit,
    output logic         sign,
    output logic signed [QW-1:0] q,
    output logic         zero_flag,
    output logic         nar_flag
);

    localparam int RW = N - 1;

    logic [N-1:0] magnitude;
    logic [RW-1:0] mag;
    logic [12:0]   qmag;

    always_comb begin
        sign      = posit[N-1];
        zero_flag = (posit == '0);
        nar_flag  = (posit == {1'b1,{(N-1){1'b0}}});

        magnitude = sign ? ((~posit) + 1'b1) : posit;
        mag       = magnitude[N-2:0];

        case (mag)
            7'd1: qmag = 13'd1;
            7'd2: qmag = 13'd2;
            7'd3: qmag = 13'd3;
            7'd4: qmag = 13'd4;
            7'd5: qmag = 13'd5;
            7'd6: qmag = 13'd6;
            7'd7: qmag = 13'd7;
            7'd8: qmag = 13'd8;
            7'd9: qmag = 13'd9;
            7'd10: qmag = 13'd10;
            7'd11: qmag = 13'd11;
            7'd12: qmag = 13'd12;
            7'd13: qmag = 13'd13;
            7'd14: qmag = 13'd14;
            7'd15: qmag = 13'd15;
            7'd16: qmag = 13'd16;
            7'd17: qmag = 13'd17;
            7'd18: qmag = 13'd18;
            7'd19: qmag = 13'd19;
            7'd20: qmag = 13'd20;
            7'd21: qmag = 13'd21;
            7'd22: qmag = 13'd22;
            7'd23: qmag = 13'd23;
            7'd24: qmag = 13'd24;
            7'd25: qmag = 13'd25;
            7'd26: qmag = 13'd26;
            7'd27: qmag = 13'd27;
            7'd28: qmag = 13'd28;
            7'd29: qmag = 13'd29;
            7'd30: qmag = 13'd30;
            7'd31: qmag = 13'd31;
            7'd32: qmag = 13'd32;
            7'd33: qmag = 13'd33;
            7'd34: qmag = 13'd34;
            7'd35: qmag = 13'd35;
            7'd36: qmag = 13'd36;
            7'd37: qmag = 13'd37;
            7'd38: qmag = 13'd38;
            7'd39: qmag = 13'd39;
            7'd40: qmag = 13'd40;
            7'd41: qmag = 13'd41;
            7'd42: qmag = 13'd42;
            7'd43: qmag = 13'd43;
            7'd44: qmag = 13'd44;
            7'd45: qmag = 13'd45;
            7'd46: qmag = 13'd46;
            7'd47: qmag = 13'd47;
            7'd48: qmag = 13'd48;
            7'd49: qmag = 13'd49;
            7'd50: qmag = 13'd50;
            7'd51: qmag = 13'd51;
            7'd52: qmag = 13'd52;
            7'd53: qmag = 13'd53;
            7'd54: qmag = 13'd54;
            7'd55: qmag = 13'd55;
            7'd56: qmag = 13'd56;
            7'd57: qmag = 13'd57;
            7'd58: qmag = 13'd58;
            7'd59: qmag = 13'd59;
            7'd60: qmag = 13'd60;
            7'd61: qmag = 13'd61;
            7'd62: qmag = 13'd62;
            7'd63: qmag = 13'd63;
            7'd64: qmag = 13'd64;
            7'd65: qmag = 13'd66;
            7'd66: qmag = 13'd68;
            7'd67: qmag = 13'd70;
            7'd68: qmag = 13'd72;
            7'd69: qmag = 13'd74;
            7'd70: qmag = 13'd76;
            7'd71: qmag = 13'd78;
            7'd72: qmag = 13'd80;
            7'd73: qmag = 13'd82;
            7'd74: qmag = 13'd84;
            7'd75: qmag = 13'd86;
            7'd76: qmag = 13'd88;
            7'd77: qmag = 13'd90;
            7'd78: qmag = 13'd92;
            7'd79: qmag = 13'd94;
            7'd80: qmag = 13'd96;
            7'd81: qmag = 13'd98;
            7'd82: qmag = 13'd100;
            7'd83: qmag = 13'd102;
            7'd84: qmag = 13'd104;
            7'd85: qmag = 13'd106;
            7'd86: qmag = 13'd108;
            7'd87: qmag = 13'd110;
            7'd88: qmag = 13'd112;
            7'd89: qmag = 13'd114;
            7'd90: qmag = 13'd116;
            7'd91: qmag = 13'd118;
            7'd92: qmag = 13'd120;
            7'd93: qmag = 13'd122;
            7'd94: qmag = 13'd124;
            7'd95: qmag = 13'd126;
            7'd96: qmag = 13'd128;
            7'd97: qmag = 13'd136;
            7'd98: qmag = 13'd144;
            7'd99: qmag = 13'd152;
            7'd100: qmag = 13'd160;
            7'd101: qmag = 13'd168;
            7'd102: qmag = 13'd176;
            7'd103: qmag = 13'd184;
            7'd104: qmag = 13'd192;
            7'd105: qmag = 13'd200;
            7'd106: qmag = 13'd208;
            7'd107: qmag = 13'd216;
            7'd108: qmag = 13'd224;
            7'd109: qmag = 13'd232;
            7'd110: qmag = 13'd240;
            7'd111: qmag = 13'd248;
            7'd112: qmag = 13'd256;
            7'd113: qmag = 13'd288;
            7'd114: qmag = 13'd320;
            7'd115: qmag = 13'd352;
            7'd116: qmag = 13'd384;
            7'd117: qmag = 13'd416;
            7'd118: qmag = 13'd448;
            7'd119: qmag = 13'd480;
            7'd120: qmag = 13'd512;
            7'd121: qmag = 13'd640;
            7'd122: qmag = 13'd768;
            7'd123: qmag = 13'd896;
            7'd124: qmag = 13'd1024;
            7'd125: qmag = 13'd1536;
            7'd126: qmag = 13'd2048;
            7'd127: qmag = 13'd4096;
            default: qmag = 13'd0;
        endcase

        if (zero_flag || nar_flag)
            q = '0;
        else if (sign)
            q = -signed'(QW'(qmag));
        else
            q = signed'(QW'(qmag));
    end
endmodule


// ============================================================================
// ADD / SUB
// ----------------------------------------------------------------------------
// Addition and subtraction are exact because q is an integer number of 1/64
// units.
// ============================================================================

module posit_addsub #(
    parameter int QW = 26
)(
    input  logic signed [QW-1:0] q_a,
    input  logic signed [QW-1:0] q_b,
    input  logic                  sub_sel,
    output logic signed [QW-1:0] num_r
);

    always_comb begin
        if (sub_sel)
            num_r = q_a - q_b;
        else
            num_r = q_a + q_b;
    end

endmodule


// ============================================================================
// MULTIPLY
// ----------------------------------------------------------------------------
// Exact result in Q units:
//      Qresult = Qa * Qb / 64
//
// Therefore the multiplier returns numerator = Qa*Qb and the top-level
// encoder receives denominator = 64. This prevents double rounding.
// ============================================================================

module posit_mul #(
    parameter int QW = 26
)(
    input  logic signed [QW-1:0] q_a,
    input  logic signed [QW-1:0] q_b,
    output logic signed [QW-1:0] num_r
);

    logic signed [13:0] qa_trunc;
    logic signed [13:0] qb_trunc;

    assign qa_trunc = q_a[13:0];
    assign qb_trunc = q_b[13:0];

    always_comb begin
        num_r = 26'(qa_trunc * qb_trunc);
    end

endmodule


// ============================================================================
// Exact rational encoder for Posit(N,0)
// ----------------------------------------------------------------------------
// Input represents:
//       exact value = (num / den) / 64
//
// For this project den is only 1 (ADD/SUB) or 64 (MUL).
//
// The encoder:
//   - handles zero and NaR
//   - saturates overflow to maxPos
//   - handles underflow below minPos
//   - rounds to nearest even
//   - constructs regime + fraction without any variable-width part-select
// ============================================================================

module posit_encoder #(
    parameter int N  = 8,
    parameter int QW = 26
)(
    input  logic signed [QW-1:0] num,
    input  logic [7:0] den,
    input  logic zero_flag,
    input  logic nar_flag,
    output logic [N-1:0] bits
);

    localparam int RW = N - 1;
    localparam int MAX_Q = 4096; // maxPos * 64

    logic [RW-1:0]       mag_code;
    logic [QW-1:0]       anum;
    logic                num_neg;
    logic [2:0]          den_extra;
    logic [4:0]          M;
    logic signed [4:0]   k_raw;
    logic [2:0]          F;
    logic [4:0]          S;
    logic [QW-1:0]       delta_num;
    logic [5:0]          frac_idx;
    logic                R;
    logic                sticky;
    logic                round_up;
    logic [5:0]          frac_cand;
    logic                carry_out;
    logic signed [3:0]   k_final;
    logic [4:0]          frac_final;

    always_comb begin
        num_neg   = (num < 0);
        anum      = num_neg ? (-num) : num;
        den_extra = (den == 8'd64) ? 3'd6 : 3'd0;

        bits      = '0;
        mag_code  = '0;

        if (nar_flag) begin
            bits = {1'b1, {(N-1){1'b0}}};
        end
        else if (zero_flag || (num == 0)) begin
            bits = '0;
        end
        else if (anum >= (MAX_Q << den_extra)) begin
            mag_code = {RW{1'b1}};
            bits = num_neg ? ((~{1'b0, mag_code}) + 1'b1) : {1'b0, mag_code};
        end
        else if (anum < den) begin
            mag_code = {{(RW-1){1'b0}}, 1'b1};
            bits = num_neg ? ((~{1'b0, mag_code}) + 1'b1) : {1'b0, mag_code};
        end
        else begin
            // Parallel Leading One Detector
            M = 5'd0;
            for (int j = 0; j < QW; j++) begin
                if (anum[j]) M = 5'(j);
            end

            k_raw = 5'(signed'({1'b0, M})) - 5'sd6 - 5'(signed'({1'b0, den_extra}));

            if (k_raw >= 0)
                F = (k_raw <= 5) ? 3'(5 - k_raw) : 3'd0;
            else
                F = (k_raw >= -6) ? 3'(6 + k_raw) : 3'd0;

            S = M - {2'b00, F};
            delta_num = anum & ~(26'd1 << M);

            if (S > 0) begin
                frac_idx = 6'(delta_num >> S);
                R = delta_num[S-1];
                if (S > 1)
                    sticky = |(delta_num & ((26'd1 << (S - 1)) - 1'b1));
                else
                    sticky = 1'b0;
            end else begin
                frac_idx = 6'(delta_num);
                R = 1'b0;
                sticky = 1'b0;
            end

            round_up = 1'b0;
            if (S > 0) begin
                if (R && sticky) begin
                    round_up = 1'b1;
                end else if (R && !sticky) begin
                    if (F > 0) begin
                        if (frac_idx[0]) round_up = 1'b1;
                    end else begin
                        if (k_raw == -6) round_up = 1'b1;
                    end
                end
            end

            frac_cand = round_up ? (frac_idx + 6'd1) : frac_idx;
            carry_out = (frac_cand >= (6'd1 << F));

            if (carry_out) begin
                k_final    = 4'(k_raw + 5'sd1);
                frac_final = 5'd0;
            end else begin
                k_final    = 4'(k_raw);
                frac_final = frac_cand[4:0];
            end

            if (k_final >= 4'sd6) begin
                mag_code = {RW{1'b1}};
            end else if (k_final <= -4'sd6) begin
                mag_code = {{(RW-1){1'b0}}, 1'b1};
            end else begin
                case (k_final)
                    -4'sd5:  mag_code = {6'b000001, frac_final[0]};
                    -4'sd4:  mag_code = {5'b00001,  frac_final[1:0]};
                    -4'sd3:  mag_code = {4'b0001,   frac_final[2:0]};
                    -4'sd2:  mag_code = {3'b001,    frac_final[3:0]};
                    -4'sd1:  mag_code = {2'b01,     frac_final[4:0]};
                     4'sd0:  mag_code = {2'b10,     frac_final[4:0]};
                     4'sd1:  mag_code = {3'b110,    frac_final[3:0]};
                     4'sd2:  mag_code = {4'b1110,   frac_final[2:0]};
                     4'sd3:  mag_code = {5'b11110,  frac_final[1:0]};
                     4'sd4:  mag_code = {6'b111110, frac_final[0]};
                     4'sd5:  mag_code = 7'b1111110;
                    default: mag_code = 7'b1111111;
                endcase
            end

            bits = num_neg ? ((~{1'b0, mag_code}) + 1'b1) : {1'b0, mag_code};
        end
    end

endmodule
