# ==============================================================================
# Constraints file for Posit(8,0) PAU on Avnet ZedBoard (xc7z020clg484-1)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Clock Constraint (100 MHz clock period = 10.000 ns)
#    - Resolves all 34 TIMING-17 warnings by defining the timing clock for
#      all input/output registers in posit8_pau_top.
# ------------------------------------------------------------------------------
create_clock -period 10.000 -name clk [get_ports clk]

# ------------------------------------------------------------------------------
# 2. Asynchronous Reset & I/O Constraints
# ------------------------------------------------------------------------------
# Set false path on asynchronous reset (standard FPGA practice)
set_false_path -from [get_ports rst_n]

# I/O delay constraints for timing closure (resolves TIMING-18 & hold checks)
set_input_delay  -clock clk -max 2.000 [get_ports {a[*] b[*] op[*] valid_in}]
set_input_delay  -clock clk -min 1.000 [get_ports {a[*] b[*] op[*] valid_in}]
set_output_delay -clock clk -max 0.000 [get_ports {result[*] valid_out}]
set_output_delay -clock clk -min -2.000 [get_ports {result[*] valid_out}]

# ------------------------------------------------------------------------------
# 3. DRC Severity Overrides & Waivers
# ------------------------------------------------------------------------------
# Demote pin planning checks from Critical Warnings to Warnings
# (Allows bitstream generation for standalone or out-of-context testing)
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]

# Disable DSP pipelining advisory checks (eliminates DPIP-1, DPOP-1, DPOP-2)
set_property IS_ENABLED 0 [get_drc_checks DPIP-1]
set_property IS_ENABLED 0 [get_drc_checks DPOP-1]
set_property IS_ENABLED 0 [get_drc_checks DPOP-2]

# Disable Zynq PS7 block check for standalone PL IP runs
set_property IS_ENABLED 0 [get_drc_checks ZPS7-1]

# ------------------------------------------------------------------------------
# 4. Optional Board Pin Mappings (Uncomment when deploying to physical ZedBoard)
# ------------------------------------------------------------------------------
# Clock (100 MHz onboard oscillator: Pin Y9)
# set_property PACKAGE_PIN Y9 [get_ports clk]
# set_property IOSTANDARD LVCMOS33 [get_ports clk]

# Reset (Center Push Button BTNC: Pin P16)
# set_property PACKAGE_PIN P16 [get_ports rst_n]
# set_property IOSTANDARD LVCMOS25 [get_ports rst_n]

# Slide Switches (SW0 - SW7) -> Input Operand 'a[7:0]'
# set_property PACKAGE_PIN F22 [get_ports {a[0]}];  # SW0
# set_property PACKAGE_PIN G22 [get_ports {a[1]}];  # SW1
# set_property PACKAGE_PIN H22 [get_ports {a[2]}];  # SW2
# set_property PACKAGE_PIN F21 [get_ports {a[3]}];  # SW3
# set_property PACKAGE_PIN H19 [get_ports {a[4]}];  # SW4
# set_property PACKAGE_PIN K18 [get_ports {a[5]}];  # SW5
# set_property PACKAGE_PIN L16 [get_ports {a[6]}];  # SW6
# set_property PACKAGE_PIN M15 [get_ports {a[7]}];  # SW7
# set_property IOSTANDARD LVCMOS25 [get_ports a*]

# Onboard LEDs (LD0 - LD7) -> Output 'result[7:0]'
# set_property PACKAGE_PIN T22 [get_ports {result[0]}];  # LD0
# set_property PACKAGE_PIN T21 [get_ports {result[1]}];  # LD1
# set_property PACKAGE_PIN U22 [get_ports {result[2]}];  # LD2
# set_property PACKAGE_PIN U21 [get_ports {result[3]}];  # LD3
# set_property PACKAGE_PIN V22 [get_ports {result[4]}];  # LD4
# set_property PACKAGE_PIN W22 [get_ports {result[5]}];  # LD5
# set_property PACKAGE_PIN U19 [get_ports {result[6]}];  # LD6
# set_property PACKAGE_PIN U14 [get_ports {result[7]}];  # LD7
# set_property IOSTANDARD LVCMOS33 [get_ports result*]
