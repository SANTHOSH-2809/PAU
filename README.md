




1. Why You Have Negative Slack (
−
50.386
 ns
−50.386 ns)

In your timing report:

Clock Period Target: 
10.000
 ns
10.000 ns (
100
 MHz
100 MHz)
Actual Data Path Delay: 
≈
60.386
 ns
≈60.386 ns
Worst Negative Slack (WNS): 
10.000
 ns
−
60.386
 ns
=
−
50.386
 ns
10.000 ns−60.386 ns=−50.386 ns
Failing Endpoints: Exactly 8 (the 8 bits of result_reg[7:0])
What is causing the 
60
 ns
60 ns delay?

In posit8_pau_top.sv, the inputs (a, b) and output (result) are registered, but the entire Posit calculation inside happens in a single clock cycle:


<img width="937" height="587" alt="image" src="https://github.com/user-attachments/assets/ebc7282e-3cef-4458-aef6-26ce8f308d80" />

In standard silicon (Xilinx 28nm Zynq-7000), a single-cycle chain of:

Posit regime leading-zero counting & fraction unpacking
32-bit fixed-point scaling
Multiplier arithmetic
Fixed-point to Posit regime search, fraction shifting, and tie-to-even rounding

takes 
≈
60
 ns
≈60 ns of combinational propagation delay. Forcing that entire chain to finish in 
10
 ns
10 ns violates setup time.
