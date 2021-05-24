# "external" simulation files

Most testbenches in this repo rely on simulating the DRAM controller operating on a simulated DDR3
memory. These testbenches currently target XSim (built-in to Vivado) and require Xilinx's DDR3
models which come with the MIG design. For licensing simplicity, we have not included these files in
source control.

To retrieve these files, right-click on the `mig_7series_0` IP module in the Vivado GUI and select
"Open IP Example Design". The opened project will include `ddr3_model_parameters.vh` and
`ddr3_model.sv`; copy these two files into the `external` folder here.
