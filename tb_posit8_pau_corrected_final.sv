`timescale 1ns/1ps

// ============================================================================
// Self-checking exhaustive testbench for the verified Posit(8,0) PAU
// ----------------------------------------------------------------------------
// The reference model is independent of the DUT.
//
// Q representation:
//     q = value * 64
//
// ADD/SUB:
//     exact q arithmetic
//
// MUL:
//     exact rational arithmetic:
//     physical value = (Qa * Qb) / (64 * 64)
//     equivalently in Q units: (Qa*Qb)/64
//
// The reference encoder searches all positive Posit(8,0) codes and applies
// round-to-nearest-even. This is intentionally simple and independent of the
// DUT's mathematical encoding algorithm.
//
// RUN_EXHAUSTIVE = 1 tests:
//     256 x 256 operand pairs x 3 operations
// ============================================================================

module tb_posit8_pau_corrected;

    localparam bit RUN_EXHAUSTIVE = 1'b0;
    localparam int RANDOM_TESTS   = 2000;


    logic [7:0] a;
    logic [7:0] b;
    logic [1:0] op;
    logic [7:0] result;

    int pass_count;
    int fail_count;

    posit8_pau dut (
        .a      (a),
        .b      (b),
        .op     (op),
        .result (result)
    );

    function automatic integer ref_decode_q(input logic [7:0] p);
        integer mag;
        integer run;
        integer kval;
        integer frac_available;
        integer frac;
        integer sign;
        integer q;
        integer j;
        integer bit_pos;
        integer found;
        begin
            if (p == 8'h00)
                return 0;

            if (p == 8'h80)
                return 0;

            sign = p[7];

            if (sign)
                mag = ((~p) + 1) & 8'hFF;
            else
                mag = p;

            run = 0;
            found = 0;

            for (j = 6; j >= 0; j = j - 1) begin
                if (!found) begin
                    if (((mag >> j) & 1) == ((mag >> 6) & 1))
                        run = run + 1;
                    else
                        found = 1;
                end
            end

            if (!found) begin
                if ((mag >> 6) & 1)
                    kval = 6;
                else
                    kval = -7;
            end
            else begin
                if ((mag >> 6) & 1)
                    kval = run - 1;
                else
                    kval = -run;
            end

            if (!found)
                frac_available = 0;
            else
                frac_available = 7 - (run + 1);

            frac = 0;

            for (j = 0; j < 5; j = j + 1) begin
                if (j < frac_available) begin
                    bit_pos = 6 - (run + 1) - j;
                    if (bit_pos >= 0)
                        frac = (frac << 1) |
                               ((mag >> bit_pos) & 1);
                end
            end

            if (kval >= -6) begin
                integer base_q;
                base_q = 1 << (kval + 6);

                if (frac_available == 0)
                    q = base_q;
                else
                    q = base_q +
                        ((frac * base_q) >> frac_available);
            end
            else
                q = 0;

            if (sign)
                q = -q;

            return q;
        end
    endfunction


    function automatic integer abs_int(input integer x);
        begin
            return (x < 0) ? -x : x;
        end
    endfunction


    function automatic logic [7:0] ref_encode_rne(
        input integer num,
        input integer den
    );
        integer anum;
        integer best_code;
        integer best_dist;
        integer distance;
        integer q;
        integer p;
        integer qmag;
        integer sign;
        begin
            sign = (num < 0);
            anum = abs_int(num);

            if (anum == 0)
                return 8'h00;

            // Underflow below minPos: saturates to minPos (SoftPosit)
            if (anum < den) begin
                best_code = 8'h01;
            end
            // MaxPos = 4096 in Q units.
            else if (anum >= 4096 * den) begin
                best_code = 8'h7F;
            end
            else begin
                best_code = 1;
                best_dist = abs_int(anum - den);

                for (p = 1; p <= 127; p = p + 1) begin
                    qmag = ref_decode_q(p[7:0]);
                    distance = abs_int(anum - qmag * den);


                    if (distance < best_dist) begin
                        best_dist = distance;
                        best_code = p;
                    end
                    else if (distance == best_dist) begin
                        // Even code wins at an exact tie.
                        if (((best_code & 1) != 0) &&
                            ((p & 1) == 0))
                            best_code = p;
                    end
                end
            end


            if (sign)
                return ((~best_code) + 1) & 8'hFF;
            else
                return best_code[7:0];
        end
    endfunction


    function automatic logic [7:0] ref_operation(
        input logic [7:0] pa,
        input logic [7:0] pb,
        input logic [1:0] pop
    );
        integer qa;
        integer qb;
        integer numerator;
        integer denominator;
        begin
            if ((pa == 8'h80) || (pb == 8'h80))
                return 8'h80;

            qa = ref_decode_q(pa);
            qb = ref_decode_q(pb);

            case (pop)
                2'b00: begin
                    numerator   = qa + qb;
                    denominator = 1;
                end

                2'b01: begin
                    numerator   = qa - qb;
                    denominator = 1;
                end

                2'b10: begin
                    numerator   = qa * qb;
                    denominator = 64;
                end

                default:
                    return 8'h80;
            endcase

            return ref_encode_rne(numerator, denominator);
        end
    endfunction


    task automatic run_case(
        input logic [7:0] ta,
        input logic [7:0] tb,
        input logic [1:0] top,
        input string name
    );
        logic [7:0] expected;
        begin
            a  = ta;
            b  = tb;
            op = top;
            #1;

            expected = ref_operation(a, b, op);

            if (result === expected) begin
                pass_count++;
                $display("PASS | %-25s | A=%02h B=%02h OP=%02b R=%02h",
                         name, a, b, op, result);
            end
            else begin
                fail_count++;
                $display("FAIL | %-25s | A=%02h B=%02h OP=%02b R=%02h EXP=%02h",
                         name, a, b, op, result, expected);
                $display("      values: Qa=%0d Qb=%0d",
                         ref_decode_q(a), ref_decode_q(b));
            end
        end
    endtask


    task automatic run_exhaustive;
        logic [7:0] expected;
        integer oper;
        integer ia;
        integer ib;
        begin
            $display("============================================================");
            $display("Starting exhaustive Posit(8,0) test:");
            $display("65536 operand pairs x 3 operations");
            $display("============================================================");

            for (oper = 0; oper < 3; oper = oper + 1) begin
                for (ia = 0; ia < 256; ia = ia + 1) begin
                    for (ib = 0; ib < 256; ib = ib + 1) begin
                        a  = ia[7:0];
                        b  = ib[7:0];
                        op = oper[1:0];
                        #1;

                        expected = ref_operation(a, b, op);

                        if (result === expected) begin
                            pass_count++;
                        end
                        else begin
                            fail_count++;

                            if (fail_count <= 20)
                                $display(
                                    "FAIL | EXHAUSTIVE | A=%02h B=%02h OP=%02b R=%02h EXP=%02h",
                                    a, b, op, result, expected
                                );
                        end
                    end
                end
            end
        end
    endtask


    initial begin
        pass_count = 0;
        fail_count = 0;

        $display("============================================================");


        $display("          Corrected Posit(8,0) PAU");
        $display("============================================================");

        // Basic tests.
        run_case(8'h00, 8'h00, 2'b00, "0 + 0");
        run_case(8'h40, 8'h40, 2'b00, "1 + 1");
        run_case(8'h20, 8'h20, 2'b00, "0.5 + 0.5");
        run_case(8'h40, 8'h20, 2'b00, "1 + 0.5");

        run_case(8'h40, 8'h40, 2'b01, "1 - 1");
        run_case(8'h40, 8'h20, 2'b01, "1 - 0.5");
        run_case(8'hC0, 8'h40, 2'b00, "-1 + 1");

        // Multiplication.
        run_case(8'h40, 8'h40, 2'b10, "1 * 1");
        run_case(8'h40, 8'h20, 2'b10, "1 * 0.5");
        run_case(8'h20, 8'h20, 2'b10, "0.5 * 0.5");
        run_case(8'hC0, 8'h40, 2'b10, "-1 * 1");
        run_case(8'hC0, 8'hC0, 2'b10, "-1 * -1");

        // Special cases.
        run_case(8'h00, 8'h40, 2'b00, "0 + 1");
        run_case(8'h00, 8'h40, 2'b10, "0 * 1");
        run_case(8'h80, 8'h40, 2'b00, "NaR + 1");
        run_case(8'h40, 8'h80, 2'b10, "1 * NaR");
        run_case(8'h40, 8'h40, 2'b11, "reserved op");

        // Scaling / boundaries.
        run_case(8'h60, 8'h40, 2'b00, "2 + 1");
        run_case(8'h60, 8'h20, 2'b01, "2 - 0.5");
        run_case(8'h01, 8'h01, 2'b00, "minpos + minpos");
        run_case(8'h01, 8'h01, 2'b10, "minpos * minpos");
        run_case(8'h7F, 8'h40, 2'b00, "maxpos + 1");
        run_case(8'hFF, 8'h40, 2'b00, "-minpos + 1");

        // Important exact-tie cases.
        run_case(8'h01, 8'h50, 2'b10, "minpos * 1.5");
        run_case(8'h7E, 8'h01, 2'b00, "32 + minpos");

        if (RUN_EXHAUSTIVE) begin
            run_exhaustive();
        end
        else begin
            for (int i = 0; i < RANDOM_TESTS; i = i + 1) begin
                a  = $urandom_range(0,255);
                b  = $urandom_range(0,255);
                op = $urandom_range(0,2);
                #1;

                if (result === ref_operation(a,b,op)) begin
                    pass_count++;
                end
                else begin
                    fail_count++;

                    if (fail_count <= 20)
                        $display(
                            "FAIL | random | A=%02h B=%02h OP=%02b R=%02h EXP=%02h",
                            a,b,op,result,ref_operation(a,b,op)
                        );
                end
            end
        end

        $display("============================================================");
        $display("PASS = %0d", pass_count);
        $display("FAIL = %0d", fail_count);

        if (fail_count == 0)
            $display("RESULT: ALL TESTS PASSED");
        else
            $display("RESULT: TESTS FAILED");

        $display("============================================================");

        $finish;
    end

endmodule
