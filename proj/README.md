## FPGA BP Vivado Project

This project instantiates a BP TinyParrot on the Arty A7-100T board, attached to the on-board
DRAM and an FPGA Host module that communicates to the host PC over UART.

This directory contains a tcl script which, when run with Vivado, generates a Vivado project
configured with appropriate settings and files.

The top-level README and accompanying Makefile automate the necessary steps; check there for usage.
However, if you would like to generate the project without the Makefile (e.g., on Windows), do the
following:
* If necessary for your host OS, source Vivado settings64.sh from the command prompt
* Run `vivado -mode batch -source fpga_bp.tcl -tclargs --blackparrot_dir <path> --arty_dir <path>`
    * The `--blackparrot_dir` argument is the base folder for BlackParrot repo without the trailing
      slash. This repo includes the black-parrot repo as a submodule under the folder name `rtl`;
      you should provide the path to that directory.
    * The `--arty_dir` argument is the base folder of this repository without the trailing slash.

On Windows machines, you may need to use single `/` characters (forward slashes) in the path, and
use abosulte paths.
