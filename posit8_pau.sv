//critical warning file

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

    integer i;
    integer j;
    integer run_count;
    integer frac_bits;
    integer frac;
    integer k;
    integer base_q;
    integer qmag;
    integer found;
    integer bit_pos;

    always_comb begin
        sign      = posit[N-1];
        zero_flag = (posit == '0);
        nar_flag  = (posit == {1'b1,{(N-1){1'b0}}});

        magnitude = sign ? ((~posit) + 1'b1) : posit;
        mag       = magnitude[N-2:0];

        run_count = 0;
        frac_bits = 0;
        frac      = 0;
        k         = 0;
        base_q    = 0;
        qmag      = 0;
        found     = 0;

        if (zero_flag || nar_flag) begin
            q = '0;
        end
        else begin
            // Count identical regime bits from the MSB of the magnitude.
            run_count = 0;
            found = 0;

            for (i = N-2; i >= 0; i = i - 1) begin
                if (!found) begin
                    if (mag[i] == mag[N-2]) begin
                        run_count = run_count + 1;
                    end
                    else begin
                        found = 1;
                    end
                end
            end

            // Determine regime k.
            if (!found) begin
                // Saturated regime.
                if (mag[N-2])
                    k = N - 2;
                else
                    k = -(N - 1);
            end
            else begin
                if (mag[N-2])
                    k = run_count - 1;
                else
                    k = -run_count;
            end

            // Number of fraction bits after regime + termination bit.
            if (!found)
                frac_bits = 0;
            else
                frac_bits = (N - 1) - (run_count + 1);

            frac = 0;

            // Extract available fraction bits.
            if (found && (frac_bits > 0)) begin
                for (j = 0; j < N-3; j = j + 1) begin
                    if (j < frac_bits) begin
                        bit_pos = (N-2) - (run_count + 1) - j;
                        if (bit_pos >= 0)
                            frac = (frac << 1) | mag[bit_pos];
                    end
                end
            end

            // q = value * 64
            //
            // value = 2^k * (1 + frac/2^F)
            // base_q = 64 * 2^k = 2^(k+6)
            //
            if (k >= -6) begin
                base_q = 1 << (k + 6);

                if (frac_bits == 0)
                    qmag = base_q;
                else
                    qmag = base_q +
                           ((frac * base_q) >> frac_bits);
            end
            else begin
                // This case is not reached by valid finite nonzero Posit(8,0)
                // values after special-case handling.
                qmag = 0;
            end

            if (sign)
                q = -qmag;
            else
                q = qmag;
        end
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

    always_comb begin
        num_r = q_a * q_b;
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
    localparam int MIN_Q = 1;    // minPos * 64

    logic [RW-1:0] mag_code;

    integer anum;
    integer k;
    integer kk;
    integer F;
    integer exp_shift;
    integer den_extra;
    integer total_shift;
    integer base_q;
    integer base_num;
    integer delta_num;
    integer scaled_num;
    integer frac_idx;
    integer rem;
    integer half;
    integer round_up;
    integer run_len;
    integer regime_len;
    integer j;
    integer pos;

    integer found_k;

    always_comb begin
        bits     = '0;
        mag_code = '0;

        anum = (num < 0) ? -num : num;

        k            = 0;
        kk           = 0;
        F            = 0;
        exp_shift    = 0;
        den_extra    = 0;
        total_shift  = 0;
        base_q       = 0;
        base_num     = 0;
        delta_num    = 0;
        scaled_num   = 0;
        frac_idx     = 0;
        rem          = 0;
        half         = 0;
        round_up     = 0;
        run_len      = 0;
        regime_len   = 0;
        found_k      = 0;

        if (nar_flag) begin
            bits = {1'b1,{(N-1){1'b0}}};
        end
        else if (zero_flag || (num == 0)) begin
            bits = '0;
        end
        else if (anum >= MAX_Q * den) begin
            // Overflow: Posit has no infinity; saturate to maxPos.
            mag_code = {RW{1'b1}};

            if (num < 0)
                bits = ((~{1'b0,mag_code}) + 1'b1);
            else
                bits = {1'b0,mag_code};
        end
        else if (anum < den) begin
            // Underflow below minPos:
            // According to the Posit standard (and SoftPosit reference implementation),
            // non-zero values that underflow below minPos saturate to +/- minPos.
            mag_code = {{(RW-1){1'b0}},1'b1};

            if (num < 0)
                bits = ((~{1'b0,mag_code}) + 1'b1);
            else
                bits = {1'b0,mag_code};
        end

        else begin
            // Find k such that:
            //     base_q <= exact_q < 2*base_q
            //
            // base_q = 2^(k+6)
            found_k = 0;

            for (kk = -6; kk <= 5; kk = kk + 1) begin
                base_q = 1 << (kk + 6);

                if (!found_k &&
                    (anum >= (base_q * den)) &&
                    (anum < (2 * base_q * den))) begin
                    k = kk;
                    found_k = 1;
                end
            end

            // Fraction width for Posit(8,0).
            if (k >= 0)
                F = 5 - k;
            else
                F = 6 + k;

            if (F < 0)
                F = 0;

            base_q = 1 << (k + 6);

            // Denominator in this scaling is a power of two.
            den_extra = (den == 8'd64) ? 6 : 0;
            exp_shift = k + 6;
            total_shift = exp_shift + den_extra;

            base_num  = base_q * den;
            delta_num = anum - base_num;
            scaled_num = delta_num << F;

            if (total_shift > 0) begin
                frac_idx = scaled_num >> total_shift;
                rem = scaled_num &
                      ((1 << total_shift) - 1);
                half = 1 << (total_shift - 1);
            end
            else begin
                frac_idx = scaled_num;
                rem = 0;
                half = 0;
            end

            round_up = 0;

            if (total_shift > 0) begin
                if (rem > half) begin
                    round_up = 1;
                end
                else if (rem == half) begin
                    if (F > 0) begin
                        // For F>0, the LSB of frac_idx is the LSB of the
                        // lower posit code.
                        if ((frac_idx & 1) != 0)
                            round_up = 1;
                    end
                    else begin
                        // For Posit(8,0), the only F=0 cases are k=-6 and
                        // k=5. At k=-6, lower code 0x01 is odd, so midpoint
                        // rounds upward. At k=5, lower code 0x7E is even,
                        // so midpoint stays at the lower value.
                        if (k == -6)
                            round_up = 1;
                    end
                end
            end

            if (round_up)
                frac_idx = frac_idx + 1;

            // If fraction rounding reaches the next scale interval,
            // restart encoding at the next k.
            if (frac_idx >= (1 << F)) begin
                k = k + 1;
                frac_idx = 0;

                if (k >= 6) begin
                    mag_code = {RW{1'b1}};

                    if (num < 0)
                        bits = ((~{1'b0,mag_code}) + 1'b1);
                    else
                        bits = {1'b0,mag_code};
                end
                else begin
                    if (k >= 0)
                        F = 5 - k;
                    else
                        F = 6 + k;

                    // Build regime.
                    mag_code = '0;

                    if (k >= 0) begin
                        run_len = k + 1;
                        regime_len = run_len + 1;

                        for (j = 0; j < RW; j = j + 1) begin
                            if (j < run_len)
                                mag_code[RW-1-j] = 1'b1;
                            else if (j == run_len)
                                mag_code[RW-1-j] = 1'b0;
                        end
                    end
                    else begin
                        run_len = -k;
                        regime_len = run_len + 1;

                        for (j = 0; j < RW; j = j + 1) begin
                            if (j < run_len)
                                mag_code[RW-1-j] = 1'b0;
                            else if (j == run_len)
                                mag_code[RW-1-j] = 1'b1;
                        end
                    end

                    // Fraction is zero after carry into the next scale.
                    if (num < 0)
                        bits = ((~{1'b0,mag_code}) + 1'b1);
                    else
                        bits = {1'b0,mag_code};
                end
            end
            else begin
                // Build regime.
                mag_code = '0;

                if (k >= 0) begin
                    run_len = k + 1;
                    regime_len = run_len + 1;

                    for (j = 0; j < RW; j = j + 1) begin
                        if (j < run_len)
                            mag_code[RW-1-j] = 1'b1;
                        else if (j == run_len)
                            mag_code[RW-1-j] = 1'b0;
                    end
                end
                else begin
                    run_len = -k;
                    regime_len = run_len + 1;

                    for (j = 0; j < RW; j = j + 1) begin
                        if (j < run_len)
                            mag_code[RW-1-j] = 1'b0;
                        else if (j == run_len)
                            mag_code[RW-1-j] = 1'b1;
                    end
                end

                // Insert fraction bits using static loop bound for synthesis.
                for (j = 0; j < RW; j = j + 1) begin
                    if (j < F) begin
                        pos = RW-1 - regime_len - j;

                        if (pos >= 0 && pos < RW) begin
                            mag_code[pos] =
                                (frac_idx >> (F-1-j)) & 1;
                        end
                    end
                end


                if (num < 0)
                    bits = ((~{1'b0,mag_code}) + 1'b1);
                else
                    bits = {1'b0,mag_code};
            end
        end
    end

endmodule
