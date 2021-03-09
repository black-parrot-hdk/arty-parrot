/**
 *
 * Name:
 *   bp_fpga_host_io_out.sv
 *
 * Description:
 *   FPGA Host IO Output module with UART Tx to PC Host and io_cmd/resp from BP
 *
 * TODO:
 * - add packet buffer on input of UART Tx
 * - FSM to process IO commands
 * -- converts IO command to NBF packet out
 * -- process io_cmd_i
 * --- most commands send NBF across UART Tx
 * -- generate io_resp_o
 * - data PISO to produce UART data packets
 * -- 8 packets, 8-bits each to one 64-bit data word
 * - address PISO to produce UART address packets
 * -- 40-bit address = 5 packets, 8-bits each
 * - process NBF packets from bp_fpga_host_io_in and send on UART
 */

module bp_fpga_host_io_out
  import bp_common_pkg::*;
  import bp_me_pkg::*;

  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter nbf_addr_width_p = paddr_width_p
    , parameter nbf_data_width_p = dword_width_gp
    , localparam nbf_width_lp = `bp_fpga_host_nbf_width(nbf_addr_width_p, nbf_data_width_p)

    , parameter uart_clk_per_bit_p = 10416 // 100 MHz clock / 9600 Baud
    , parameter uart_data_bits_p = 8 // between 5 and 9 bits
    , parameter uart_parity_bit_p = 0 // 0 or 1
    , parameter uart_stop_bits_p = 1 // 1 or 2

    `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, io)
    )
  (input                                     clk_i
   , input                                   reset_i

   // From BlackParrot
   , input [io_mem_msg_width_lp-1:0]         io_cmd_i
   , input                                   io_cmd_v_i
   , output logic                            io_cmd_ready_and_o

   , output logic [io_mem_msg_width_lp-1:0]  io_resp_o
   , output logic                            io_resp_v_o
   , input                                   io_resp_yumi_i

   // UART to PC Host
   , output logic                            tx_o

   // Signals from FPGA Host IO In
   , input                                   fence_done_i
   , input                                   rx_error_i
   , input [nbf_width_lp-1:0]                nbf_i
   , input                                   nbf_v_i
   , output logic                            nbf_yumi_o
   );

  wire tx_v_li, tx_yumi_lo, tx_v_lo, tx_done_lo;
  wire [uart_data_bits_p-1:0] tx_data_li;
  uart_tx
   #(.clk_per_bit_p(uart_clk_per_bit_p)
     ,.data_bits_p(uart_data_bits_p)
     ,.parity_bit_p(uart_parity_bit_p)
     ,.stop_bits_p(uart_stop_bits_p)
     )
    tx
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     // input
     ,.tx_v_i(tx_v_li)
     ,.tx_i(tx_data_li)
     ,.tx_yumi_o(tx_yumi_lo)
     // output
     ,.tx_v_o(tx_v_lo)
     ,.tx_o(tx_o)
     ,.tx_done_o(tx_done_lo)
     );

endmodule
