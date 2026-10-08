`timescale 1ns/1ps

// ============================================================================
// Self-Checking Testbench for Pipelined Posit(8,0) PAU Top (posit8_pau_top)
// ----------------------------------------------------------------------------
// Latency   : Exactly 5 clock cycles
// Throughput: 1 operation per clock cycle (streaming pipeline @ 100 MHz)
// Verified against the SoftPosit-compliant independent reference model
// ============================================================================

module tb_posit8_pau_top;

    localparam int CLK_PERIOD = 10; // 100 MHz (10.000 ns)
    localparam int TEST_COUNT = 2000;

    logic        clk;
    logic        rst_n;
    logic        valid_in;
    logic [7:0]  a;
    logic [7:0]  b;
    logic [1:0]  op;
    logic        valid_out;
    logic [7:0]  result;

    // Expected queue for pipelined checking
    typedef struct {
        logic [7:0] a;
        logic [7:0] b;
        logic [1:0] op;
        logic [7:0] exp_res;
    } test_item_t;

    test_item_t exp_q[$];
    int pass_count = 0;
    int fail_count = 0;

    // DUT instantiation
    posit8_pau_top dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (valid_in),
        .a         (a),
        .b         (b),
        .op        (op),
        .valid_out (valid_out),
        .result    (result)
    );

    // ========================================================================
    // Golden Reference Model
    // ========================================================================
    function automatic integer ref_decode_q(input logic [7:0] p);
        integer mag, run, kval, frac_available, frac, sign, q, j, bit_pos, found;
        begin
            if (p == 8'h00 || p == 8'h80) return 0;
            sign = p[7];
            mag = sign ? (((~p) + 1) & 8'hFF) : p;
            run = 0; found = 0;
            for (j = 6; j >= 0; j = j - 1) begin
                if (!found) begin
                    if (((mag >> j) & 1) == ((mag >> 6) & 1)) run = run + 1;
                    else found = 1;
                end
            end
            if (!found) kval = ((mag >> 6) & 1) ? 6 : -7;
            else kval = ((mag >> 6) & 1) ? (run - 1) : -run;

            frac_available = (!found) ? 0 : (7 - (run + 1));
            frac = 0;
            if (found && (frac_available > 0)) begin
                for (j = 0; j < 5; j = j + 1) begin
                    if (j < frac_available) begin
                        bit_pos = 6 - (run + 1) - j;
                        if (bit_pos >= 0) frac = (frac << 1) | ((mag >> bit_pos) & 1);
                    end
                end
            end
            if (kval >= -6) begin
                if (frac_available == 0) q = (1 << (kval + 6));
                else q = (1 << (kval + 6)) + ((frac * (1 << (kval + 6))) >> frac_available);
            end else q = 0;
            return sign ? -q : q;
        end
    endfunction

    function automatic integer abs_int(input integer x);
        return (x < 0) ? -x : x;
    endfunction

    function automatic logic [7:0] ref_encode_rne(input integer num, input integer den);
        integer anum, best_code, best_dist, distance, p, qmag, sign;
        begin
            sign = (num < 0);
            anum = abs_int(num);
            if (anum == 0) return 8'h00;
            if (anum < den) best_code = 8'h01;
            else if (anum >= 4096 * den) best_code = 8'h7F;
            else begin
                best_code = 1;
                best_dist = abs_int(anum - den);
                for (p = 1; p <= 127; p = p + 1) begin
                    qmag = ref_decode_q(p[7:0]);
                    distance = abs_int(anum - qmag * den);
                    if (distance < best_dist) begin
                        best_dist = distance;
                        best_code = p;
                    end else if (distance == best_dist) begin
                        if (((best_code & 1) != 0) && ((p & 1) == 0))
                            best_code = p;
                    end
                end
            end
            return sign ? (((~best_code) + 1) & 8'hFF) : best_code[7:0];
        end
    endfunction

    function automatic logic [7:0] ref_operation(input logic [7:0] pa, input logic [7:0] pb, input logic [1:0] pop);
        integer qa, qb, num, den;
        begin
            if ((pa == 8'h80) || (pb == 8'h80)) return 8'h80;
            qa = ref_decode_q(pa);
            qb = ref_decode_q(pb);
            case (pop)
                2'b00: begin num = qa + qb; den = 1; end
                2'b01: begin num = qa - qb; den = 1; end
                2'b10: begin num = qa * qb; den = 64; end
                default: return 8'h80;
            endcase
            return ref_encode_rne(num, den);
        end
    endfunction

    // Clock Generation (100 MHz)
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Stimulus and Queueing
    initial begin
        clk      = 0;
        rst_n    = 0;
        valid_in = 0;
        a        = 0;
        b        = 0;
        op       = 0;

        // Reset pulse
        #(CLK_PERIOD * 3);
        rst_n = 1;
        #(CLK_PERIOD * 2);

        $display("============================================================");
        $display("  Starting Pipelined Posit(8,0) PAU Top Testbench (100 MHz)");
        $display("============================================================");

        // Feed corner cases
        feed_op(8'h00, 8'h00, 2'b00); // 0 + 0
        feed_op(8'h40, 8'h40, 2'b00); // 1 + 1
        feed_op(8'h40, 8'h20, 2'b00); // 1 + 0.5
        feed_op(8'h40, 8'h40, 2'b01); // 1 - 1
        feed_op(8'h40, 8'h20, 2'b01); // 1 - 0.5
        feed_op(8'hc0, 8'h40, 2'b00); // -1 + 1
        feed_op(8'h40, 8'h40, 2'b10); // 1 * 1
        feed_op(8'h40, 8'h20, 2'b10); // 1 * 0.5
        feed_op(8'hc0, 8'h40, 2'b10); // -1 * 1
        feed_op(8'hc0, 8'hc0, 2'b10); // -1 * -1
        feed_op(8'h80, 8'h40, 2'b00); // NaR + 1
        feed_op(8'h40, 8'h80, 2'b10); // 1 * NaR
        feed_op(8'h40, 8'h40, 2'b11); // reserved op
        feed_op(8'h01, 8'h01, 2'b00); // minpos + minpos
        feed_op(8'h01, 8'h01, 2'b10); // minpos * minpos
        feed_op(8'h7f, 8'h40, 2'b00); // maxpos + 1
        feed_op(8'hff, 8'h40, 2'b00); // -minpos + 1
        feed_op(8'h01, 8'h50, 2'b10); // minpos * 1.5
        feed_op(8'h7e, 8'h01, 2'b00); // 32 + minpos

        // Streaming random test vectors
        for (int i = 0; i < TEST_COUNT; i++) begin
            logic [7:0] ra, rb;
            logic [1:0] rop;
            ra  = $urandom_range(0, 255);
            rb  = $urandom_range(0, 255);
            rop = $urandom_range(0, 2);
            feed_op(ra, rb, rop);
        end

        // End of stimulus
        @(posedge clk);
        valid_in = 0;

        // Wait for pipeline to drain
        #(CLK_PERIOD * 10);

        $display("============================================================");
        $display("PASS = %0d", pass_count);
        $display("FAIL = %0d", fail_count);
        if (fail_count == 0 && pass_count > 0)
            $display("RESULT: ALL PIPELINED TESTS PASSED (100%% EXACT MATCH)");
        else
            $display("RESULT: TEST FAILED WITH %0d MISMATCHES", fail_count);
        $display("============================================================");

        $finish;
    end

    task feed_op(input logic [7:0] in_a, input logic [7:0] in_b, input logic [1:0] in_op);
        test_item_t item;
        item.a       = in_a;
        item.b       = in_b;
        item.op      = in_op;
        item.exp_res = ref_operation(in_a, in_b, in_op);
        exp_q.push_back(item);

        @(posedge clk);
        valid_in = 1;
        a        = in_a;
        b        = in_b;
        op       = in_op;
    endtask

    // Output Checker on valid_out
    always @(posedge clk) begin
        if (rst_n && valid_out) begin
            if (exp_q.size() > 0) begin
                test_item_t exp = exp_q.pop_front();
                if (result === exp.exp_res) begin
                    pass_count++;
                end else begin
                    $display("FAIL | A=%02h B=%02h OP=%0b | EXP=%02h GOT=%02h",
                             exp.a, exp.b, exp.op, exp.exp_res, result);
                    fail_count++;
                end
            end else begin
                $display("ERROR: Unexpected valid_out with empty expected queue!");
                fail_count++;
            end
        end
    end

endmodule
