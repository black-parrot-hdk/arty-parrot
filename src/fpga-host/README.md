## FPGA Host Project
This project instantiates the FPGA Host on the Arty A7-100T board with a simple loopback
attached to the IO command and response ports.

To create the project:
* source Vivado settings64.sh from the command prompt
* run `vivado -mode batch -source fpga_host_test.tcl -tclargs --blackparrot_dir <path> --arty_dir <path>`
* the `--blackparrot_dir` argument is the base folder for BlackParrot repo without the trailing slash
* the `--arty_dir` argument is the base folder of this repository without the trailing slash

## Baud Rates
The FPGA Host has been tested at a Baud Rate of 9600, and the UART Rx/Tx up to 115200.
The host project should have no issues at a Baud Rate of at least 115200.

To set a Baud Rate of 115200, set the `uart_clk_per_bit_p` parameter to 868 in bp\_fpga\_host.sv.
