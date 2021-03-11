/**
 *
 * Name:
 *   bp_fpga_host_io_out.sv
 *
 * Description:
 *   FPGA Host IO Output module with UART Tx to PC Host and io_cmd/resp from BP
 *
 * Inputs:
 *   io_cmd_i - IO requests from BlackParrotA
 *            - includes core done, put char (global or core specific), error (TBD)
 *            - lowest priority, can block
 *
 *   nbf_i - NBF responses from bp_fpga_host_io_in.sv
 *         - includes nbf finish, nbf fence done, UART RX error, memory read response
 *         - highest priority (cannot block UART RX in bp_fpga_host_io_in)
 *
 * Outputs:
 *   io_resp_o - response to io_cmd_i messages
 *             - respond with ack to BP as soon as cmd is processed
 *
 *
 * TODO:
 * NBF buffer (bsg_two_fifo)
 * - inputs from FSM and nbf_i arbitration
 * - fixed priority to nbf_i buffer
 *
 * nbf_i buffer (bsg_two_fifo)
 * - buffer NBF packets from bp_fpga_host_io_in
 *
 * PISO (bsg_parallel_in_serial_out_passthrough)
 * - converts NBF buffer packets to UART TX
 * - opcode + addr + data = 1 + 5 + 8 bytes = 14 bytes on input
 * - 1 byte on output
 * - send over UART TX should be opcode then address then data
 * - address and data should send LSB to MSB (or MSB to LSB?)
 *
 * FSM to process io_cmd_i
 * - converts IO command to NBF packet
 * - generate io_resp_o
 *
 * Arbitration from FSM and nbf_i buffer (bsg_arb_fixed)
 * - fixed priority to nbf_i buffer
 * - FSM is allowed to block on processing io_cmd_i
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

    , parameter nbf_buffer_els_p = 4

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
   , input [nbf_width_lp-1:0]                nbf_i
   , input                                   nbf_v_i
   , output logic                            nbf_ready_and_o
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
