## FPGA Configuration I/O Options
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

# Clock signal
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { external_clock_i }]; #IO_L12P_T1_MRCC_35 Sch=gclk[100]
create_clock -add -name external_clock_i -period 10.00 -waveform {0 5}  [get_ports { external_clock_i }];

# reset button
set_property -dict { PACKAGE_PIN C2    IOSTANDARD LVCMOS33 } [get_ports { external_reset_n_i }]; #IO_L6N_T0_VREF_16 Sch=btn[0]

# LED
set_property -dict { PACKAGE_PIN H5    IOSTANDARD LVCMOS33 } [get_ports { wr_error_led_o }]; #IO_L24N_T3_35 Sch=led[4]
set_property -dict { PACKAGE_PIN J5    IOSTANDARD LVCMOS33 } [get_ports { rd_error_led_o }]; #IO_25_35 Sch=led[5]
set_property -dict { PACKAGE_PIN T9    IOSTANDARD LVCMOS33 } [get_ports { done_led_o }]; #IO_L24P_T3_A01_D17_14 Sch=led[6]
set_property -dict { PACKAGE_PIN T10   IOSTANDARD LVCMOS33 } [get_ports { reset_led_o }]; #IO_L24N_T3_A00_D16_14 Sch=led[7]