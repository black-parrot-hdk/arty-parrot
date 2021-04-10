## FPGA BP Project
This project instantiates a BP TinyParrot on the Arty A7-100T board, attached to the on-board
DRAM and an FPGA Host module that communicates to the host PC over UART.

To create the project:
* source Vivado settings64.sh from the command prompt
* run `vivado -mode batch -source fpga_host_test.tcl -tclargs --blackparrot_dir <path> --arty_dir <path>`
* the `--blackparrot_dir` argument is the base folder for BlackParrot repo without the trailing slash
* the `--arty_dir` argument is the base folder of this repository without the trailing slash
* note: on Windows machines, use single `/` characters (forward slashes) in the path, and use abosulte paths

