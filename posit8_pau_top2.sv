`timescale 1ns/1ps

// ============================================================================
// Pipelined / Registered Top Wrapper for Posit(8,0) Arithmetic Unit
// ----------------------------------------------------------------------------
// Target Device: Xilinx Zynq-7000 (ZedBoard: xc7z020clg484-1)
//
// Purpose:
// 1. Adds input and output registers to pipeline DSP48E1 arithmetic slices.
//    This allows Vivado to absorb DSP registers (AREG, BREG, MREG, PREG),
//    eliminating all DPIP-1, DPOP-1, and DPOP-2 warnings while maximizing Fmax.
// 2. Provides clean clock (clk) and reset (rst_n) interfaces for FPGA synthesis.
// 3. Includes an optional parameter PIPELINE_STAGES:
//      - PIPELINE_STAGES = 2 (default): Fully registered for optimal DSP timing.
//      - PIPELINE_STAGES = 0: Pure combinational passthrough.
// ============================================================================

module posit8_pau_top #(
    parameter int N = 8,
    parameter int PIPELINE_STAGES = 2
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
    // Internal Signals
    // ========================================================================
    logic [N-1:0] a_reg, b_reg;
    logic [1:0]   op_reg;
    logic         valid_reg;

    logic [N-1:0] core_result;

    // ========================================================================
    // Core PAU Instantiation (Combinational Math Engine)
    // ========================================================================
    posit8_pau #(.N(N)) u_pau_core (
        .a      (PIPELINE_STAGES > 0 ? a_reg  : a),
        .b      (PIPELINE_STAGES > 0 ? b_reg  : b),
        .op     (PIPELINE_STAGES > 0 ? op_reg : op),
        .result (core_result)
    );

    // ========================================================================
    // Pipeline Registers
    // ========================================================================
    generate
        if (PIPELINE_STAGES >= 2) begin : gen_pipelined_stages
            // Input Stage Registers
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    a_reg     <= '0;
                    b_reg     <= '0;
                    op_reg    <= '0;
                    valid_reg <= 1'b0;
                end else begin
                    a_reg     <= a;
                    b_reg     <= b;
                    op_reg    <= op;
                    valid_reg <= valid_in;
                end
            end

            // Output Stage Registers
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    result    <= '0;
                    valid_out <= 1'b0;
                end else begin
                    result    <= core_result;
                    valid_out <= valid_reg;
                end
            end
        end
        else if (PIPELINE_STAGES == 1) begin : gen_single_stage
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    result    <= '0;
                    valid_out <= 1'b0;
                end else begin
                    result    <= core_result;
                    valid_out <= valid_in;
                end
            end
            assign a_reg     = a;
            assign b_reg     = b;
            assign op_reg    = op;
            assign valid_reg = valid_in;
        end
        else begin : gen_pure_combinational
            // Pure combinational passthrough
            assign result    = core_result;
            assign valid_out = valid_in;
            assign a_reg     = a;
            assign b_reg     = b;
            assign op_reg    = op;
            assign valid_reg = valid_in;
        end
    endgenerate

endmodule
