# Clock Signal
# Assign pin E3 to clk_50MHz with proper IOSTANDARD
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports clk_50MHz]; # IO_L12P_T1_MRCC_35 Sch=clk100mhz

# Define a 20.00ns (50MHz) clock
create_clock -name clk_50MHz -period 20.00 [get_ports clk_50MHz];

# DAC Signal Assignments
set_property -dict { PACKAGE_PIN D18 IOSTANDARD LVCMOS33 } [get_ports { dac_LRCK }];  # IO_L21N_T3_DQS_A18_15 Sch=ja[2]
set_property -dict { PACKAGE_PIN E18 IOSTANDARD LVCMOS33 } [get_ports { dac_SCLK }];  # IO_L21P_T3_DQS_15 Sch=ja[3]
set_property -dict { PACKAGE_PIN G17 IOSTANDARD LVCMOS33 } [get_ports { dac_SDIN }];  # IO_L18N_T2_A23_15 Sch=ja[4]
set_property -dict { PACKAGE_PIN C17 IOSTANDARD LVCMOS33 } [get_ports { dac_MCLK }];  # IO_L20N_T3_A19_15 Sch=ja[1]
