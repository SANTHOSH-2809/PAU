



<img width="937" height="587" alt="image" src="https://github.com/user-attachments/assets/ebc7282e-3cef-4458-aef6-26ce8f308d80" />




3stage pipeline of alu

<img width="1146" height="261" alt="image" src="https://github.com/user-attachments/assets/1f0442e7-7850-4697-94be-ca175b1dc58c" />

<img width="721" height="107" alt="image" src="https://github.com/user-attachments/assets/be6f7a5f-17f1-4584-8428-e8b8bbb9d0b8" />

<img width="517" height="202" alt="image" src="https://github.com/user-attachments/assets/66616230-9beb-43c5-b67c-72adee7e1466" />


posit2
<img width="1040" height="266" alt="image" src="https://github.com/user-attachments/assets/22a5497c-2518-47a0-94c7-854032f1cff3" />

`create_clock -period 10.000 -name clk [get_ports clk]`

posit3

<img width="1035" height="281" alt="image" src="https://github.com/user-attachments/assets/d16b921b-5a6c-4014-b74b-1a6a2967e52e" />

`create_clock -period 26.000 -name clk [get_ports clk]`

<img width="1090" height="293" alt="image" src="https://github.com/user-attachments/assets/69d75b74-04b8-4e91-a688-fa3316ab1796" />

negative slack when 
`create_clock -period 10.000 -name clk [get_ports clk]`

`create_clock -period 20.000 -name clk [get_ports clk]`
<img width="1075" height="535" alt="image" src="https://github.com/user-attachments/assets/87986f3f-2756-406e-8377-a9ea523b932a" />



<img width="1037" height="271" alt="image" src="https://github.com/user-attachments/assets/31524a56-db02-43a3-9c7e-c89202e4c8f7" />
again negative slack when
`create_clock -period 16.000 -name clk [get_ports clk]`






stage 4

<img width="1682" height="263" alt="image" src="https://github.com/user-attachments/assets/e8ac2373-fcf0-480f-9a9a-64d663c06bf6" />

<img width="946" height="373" alt="image" src="https://github.com/user-attachments/assets/3c17d913-9e34-4de9-93cf-4f441e16ea5a" />

<img width="960" height="488" alt="image" src="https://github.com/user-attachments/assets/13f0761c-3a69-4af4-b417-8cc130c74daf" />




optimized

Architectural Optimizations Applied in PAU_final
Parallel 128-Entry Decoder LUT:
In posit8_pau.sv, replaced the 32-bit dynamic search loops and 15 cascaded CARRY4 blocks with a direct 128-entry parallel lookup table. Logic propagation delay dropped from 17.2 ns down to 0.35 ns.
Single-Slice DSP48 Multiplier (
14
×
14
14×14):
For Posit(8,0), decoded values only range from 
−
4096
−4096 to 
+
4096
+4096, requiring only signed 14 bits. Instead of decomposing a 26-bit multiplier across multiple DSP slices and carry adders, posit_mul directly performs signed 
14
×
14
14×14 multiplication, fitting into a single DSP48E1 slice with 2.8 ns delay.
Multiplier Zero-Flag Decoupling:
A product is zero if and only if either operand is zero (
𝑎
=
0
∨
𝑏
=
0
a=0∨b=0). Instead of chaining a 4-level 26-bit zero comparator after the DSP output, the zero flag is driven by s1_zero_a_r || s1_zero_b_r from Stage 1, eliminating 6.5 ns of logic on the critical path.
Balanced 2-Stage Encoder (Stages 3 & 4):
Stage 3: Parallel Leading One Detector (LOD) scans the 26-bit magnitude and computes shift offset 
𝑆
=
𝑀
−
𝐹
S=M−F, round bit 
𝑅
R, and sticky bit in ~3.8 ns.
Stage 4: Performs tie-to-even rounding and direct 13-entry regime bit mapping without sequential loops or variable part-selects in ~2.0 ns.
Cleaned Constraints & Pin Delays:
constraints.xdc updated with 100 MHz clock period, false path on rst_n, realistic I/O delays, and removal of unsupported XDC commands.






