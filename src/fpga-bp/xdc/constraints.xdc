## FPGA Configuration I/O Options
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

# Clock signal
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { sys_clk_i }]; #IO_L12P_T1_MRCC_35 Sch=gclk[100]
create_clock -add -name sys_clk_i -period 10.00 -waveform {0 5}  [get_ports { sys_clk_i }];

# USB-UART Interface
# output
set_property -dict { PACKAGE_PIN D10   IOSTANDARD LVCMOS33 } [get_ports { tx_o }]; #IO_L19N_T3_VREF_16 Sch=uart_txd_out
# input
set_property -dict { PACKAGE_PIN A9    IOSTANDARD LVCMOS33 } [get_ports { rx_i }]; #IO_L14N_T2_SRCC_16 Sch=uart_rxd_in

# button as reset
set_property -dict { PACKAGE_PIN D9    IOSTANDARD LVCMOS33 } [get_ports { reset_i }]; #IO_L6N_T0_VREF_16 Sch=btn[0]
# button to send
# set_property -dict { PACKAGE_PIN C9    IOSTANDARD LVCMOS33 } [get_ports { send_i }]; #IO_L11P_T1_SRCC_16 Sch=btn[1]

# LED
set_property -dict { PACKAGE_PIN H5    IOSTANDARD LVCMOS33 } [get_ports { error_o }]; #IO_L24N_T3_35 Sch=led[4]
set_property -dict { PACKAGE_PIN J5    IOSTANDARD LVCMOS33 } [get_ports { reset_o }]; #IO_25_35 Sch=led[5]