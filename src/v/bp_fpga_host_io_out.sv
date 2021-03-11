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

  `declare_bp_fpga_host_nbf_s(nbf_addr_width_p, nbf_data_width_p);

  bp_fpga_host_nbf_s nbf_li;
  logic nbf_v, nbf_yumi;

  // buffer from nbf_i to arbitration
  bsg_two_fifo
   #(.width_p(nbf_width_lp))
    nbf_in_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // from nbf_i
      ,.v_i(nbf_v_i)
      ,.ready_o(nbf_ready_and_o)
      ,.data_i(nbf_i)
      // to arbitration
      ,.v_o(nbf_v)
      ,.yumi_i(nbf_yumi)
      ,.data_o(nbf_li)
      );

  // nbf packet from FSM processing io_cmd_i
  bp_fpga_host_nbf_s io_nbf;
  logic io_nbf_v, io_nbf_yumi;

  // UART TX signals
  logic tx_v_li, tx_ready_and_lo, tx_v_lo, tx_done_lo;
  logic [uart_data_bits_p-1:0] tx_data_li;

  // NBF PISO signals
  logic nbf_piso_ready_and_lo;

  // NBF buffer output signals
  logic nbf_buffer_v_lo, nbf_buffer_yumi_li;
  bp_fpga_host_nbf_s nbf_buffer_lo;
  assign nbf_buffer_yumi_li = nbf_buffer_v_lo & nbf_piso_ready_and_lo;

  // NBF buffer input signals
  logic nbf_buffer_v_li, nbf_buffer_ready_and_lo;
  bp_fpga_host_nbf_s nbf_buffer_li;
  // choose nbf_i buffer if available, else io_nbf from FSM
  assign nbf_buffer_li = nbf_v ? nbf_li : io_nbf;
  // input to buffer is valid if either nbf_i or FSM has valid nbf to send
  assign nbf_buffer_v_li = nbf_v | io_nbf_v;
  // priority to nbf buffer goes to nbf_i
  assign nbf_yumi = nbf_v & nbf_buffer_ready_and_lo;
  // else, can handshake with FSM
  assign io_nbf_yumi = ~nbf_v & io_nbf_v & nbf_buffer_ready_and_lo;

  // buffer from arbitration to PISO
  bsg_fifo_1r1w_small
   #(.width_p(nbf_width_lp)
     ,.els_p(nbf_buffer_els_p)
     ,.ready_THEN_valid_p(0)
     )
    nbf_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     // from arbitration
     ,.v_i(nbf_buffer_v_li)
     ,.ready_o(nbf_buffer_ready_and_lo)
     ,.data_i(nbf_buffer_li)
     // to piso
     ,.v_o(nbf_buffer_v_lo)
     ,.data_o(nbf_buffer_lo)
     ,.yumi_i(nbf_buffer_yumi_li)
     );

  bsg_parallel_in_serial_out_passthrough
   #(.width_p(uart_data_bits_p)
     ,.els_p(nbf_uart_packets_lp)
     ,.hi_to_lo_p(0)
     // byte order sent across UART TX should be opcode byte, followed by LSB to MSB
     // of address then LSB to MSB of data
     )
    nbf_piso
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     // from nbf buffer
     ,.v_i(nbf_buffer_v_lo)
     ,.data_i(nbf_buffer_lo)
     ,.ready_and_o(nbf_piso_ready_and_lo)
     // to uart tx
     ,.data_o(tx_data_li)
     ,.v_o(tx_v_li)
     ,.ready_and_i(tx_ready_and_lo)
     );

  // UART TX
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
     ,.tx_ready_and_o(tx_ready_and_lo)
     // output
     ,.tx_v_o(tx_v_lo)
     ,.tx_o(tx_o)
     ,.tx_done_o(tx_done_lo)
     );


  typedef enum logic [3:0]
  {

  } io_out_state_e;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
    end else begin
    end
  end

  always_comb begin
  end

endmodule
