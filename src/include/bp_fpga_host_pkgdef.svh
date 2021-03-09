`ifndef BP_FPGA_HOST_PKGDEF_SVH
`define BP_FPGA_HOST_PKGDEF_SVH

  /*
   * FPGA Host NBF Commands
   *
   * Commands are defined
   *
   */
  typedef enum logic [7:0]
  {
    // To FPGA from PC
    e_fpga_host_nbf_write_4     = 8'b0000_0010 // Write 4 bytes (no reply sent)
    ,e_fpga_host_nbf_write_8    = 8'b0000_0011 // Write 8 bytes (no reply sent)
    ,e_fpga_host_nbf_read_4     = 8'b0001_0010 // Read 4 bytes (reply with data)
    ,e_fpga_host_nbf_read_8     = 8'b0001_0011 // Read 8 bytes (reply with data)

    // From FPGA to PC
    ,e_fpga_host_nbf_core_done  = 8'b1000_0000 // Core finished (data[0+:8] = core ID)
    ,e_fpga_host_nbf_error      = 8'b1000_0001 // Error from FPGA
    ,e_fpga_host_nbf_putch      = 8'b1000_0010 // Put Char from FPGA (global)
    ,e_fpga_host_nbf_putch_core = 8'b1000_0011 // Put Char from FPGA (core specific)

    // To FPGA with ack back to PC
    ,e_fpga_host_nbf_fence      = 8'b1111_1110 // Fence
    ,e_fpga_host_nbf_finish     = 8'b1111_1111 // Finish NBF load to FPGA
  } bp_fpga_host_nbf_opcode_e;

`endif
