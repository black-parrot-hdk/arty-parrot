## FPGA Configuration I/O Options
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

# Clock signal
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { master_clk_100mhz_i }]; #IO_L12P_T1_MRCC_35 Sch=gclk[100]
create_clock -add -name master_clk_100mhz_i -period 10.00 -waveform {0 5}  [get_ports { master_clk_100mhz_i }];

# USB-UART Interface
# output
# set_property -dict { PACKAGE_PIN D10   IOSTANDARD LVCMOS33 } [get_ports { tx_o }]; #IO_L19N_T3_VREF_16 Sch=uart_txd_out
# input
# set_property -dict { PACKAGE_PIN A9    IOSTANDARD LVCMOS33 } [get_ports { rx_i }]; #IO_L14N_T2_SRCC_16 Sch=uart_rxd_in

# switches
set_property -dict { PACKAGE_PIN A8    IOSTANDARD LVCMOS33 } [get_ports { input_select_switch_i }]; #IO_L6N_T0_VREF_16 Sch=btn[0]

# reset button
set_property -dict { PACKAGE_PIN C2    IOSTANDARD LVCMOS33 } [get_ports { master_reset_active_low_i }]; #IO_L6N_T0_VREF_16 Sch=btn[0]

# LED
set_property -dict { PACKAGE_PIN H5    IOSTANDARD LVCMOS33 } [get_ports { pass_led_o }]; #IO_L24N_T3_35 Sch=led[4]
set_property -dict { PACKAGE_PIN J5    IOSTANDARD LVCMOS33 } [get_ports { reset_led_o }]; #IO_25_35 Sch=led[5]

# DRAM
# PadFunction: IO_L8P_T1_AD14P_35 
# set_property IOSTANDARD LVCMOS25 [get_ports {init_calib_complete}]
# set_property PACKAGE_PIN A4 [get_ports {init_calib_complete}]

# PadFunction: IO_L10N_T1_AD15N_35 
# set_property IOSTANDARD LVCMOS25 [get_ports {tg_compare_error}]
# set_property PACKAGE_PIN B2 [get_ports {tg_compare_error}]


set_property INTERNAL_VREF  0.675 [get_iobanks 34]

# Suppress [Place 30-172] Sub-optimal placement for a clock-capable IO pin and PLL pair.
# TODO: investigate running the 100MHz clock through the MMCM instead
set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets master_clk_100mhz_i_IBUF]