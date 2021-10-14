`ifndef BP_MIG_DDR3_RAM_INTERFACE_SVH
`define BP_MIG_DDR3_RAM_INTERFACE_SVH

// Expands to define all ports necessary for the native DDR3 interface which can be passed to MIG components.
// No leading or trailing commas are included.
`define declare_mig_ddr3_native_control_ports \
/* Inouts */ \
inout [15:0]  ddr3_dq, \
inout [1:0]   ddr3_dqs_n, \
inout [1:0]   ddr3_dqs_p, \
\
/* Outputs */ \
output [13:0] ddr3_addr, \
output [2:0]  ddr3_ba, \
output        ddr3_ras_n, \
output        ddr3_cas_n, \
output        ddr3_we_n, \
output        ddr3_reset_n, \
output [0:0]  ddr3_ck_p, \
output [0:0]  ddr3_ck_n, \
output [0:0]  ddr3_cke, \
\
output [0:0]  ddr3_cs_n, \
\
output [1:0]  ddr3_dm, \
\
output [0:0]  ddr3_odt
`endif
