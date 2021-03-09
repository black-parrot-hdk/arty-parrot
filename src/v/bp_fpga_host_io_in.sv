/**
 *
 * Name:
 *   bp_fpga_host_io_in.sv
 *
 * Description:
 *   FPGA Host IO Input module with UART Rx from PC Host and io_cmd/resp to BP
 *
 *
 * TODO:
 * - add packet buffer on output of UART Rx
 * -- rx_error_o on enqueue to buffer if buffer full
 * - FSM to process NBF packets
 * -- converts NBF command to IO command
 * -- generate io_cmd_o
 * -- process io_resp_i
 * --- some responses require sending nbf packet to bp_fpga_host_io_out
 * - credit counter for io_cmd_o/io_resp_i
 * - data SIPO to capture UART data packets
 * -- 8 packets, 8-bits each to one 64-bit data word
 * - address SIPO to capture UART address packets
 * -- 40-bit address = 5 packets, 8-bits each
 */

module bp_fpga_host_io_in
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

   // To BlackParrot
   , output logic [io_mem_msg_width_lp-1:0]  io_cmd_o
   , output logic                            io_cmd_v_o
   , input                                   io_cmd_yumi_i

   , input  [io_mem_msg_width_lp-1:0]        io_resp_i
   , input                                   io_resp_v_i
   , output logic                            io_resp_ready_and_o

   // UART to PC Host
   , input                                   rx_i

   // Signals to FPGA Host IO Out
   , output logic                            fence_done_o
   , output logic                            rx_error_o
   , output logic [nbf_width_lp-1:0]         nbf_o
   , output logic                            nbf_v_o
   , input                                   nbf_yumi_i
   );

  wire rx_v_lo, rx_error_lo;
  wire [uart_data_bits_p-1:0] rx_data_lo;
  uart_rx
   #(.clk_per_bit_p(uart_clk_per_bit_p)
     ,.data_bits_p(uart_data_bits_p)
     ,.parity_bit_p(uart_parity_bit_p)
     ,.stop_bits_p(uart_stop_bits_p)
     )
    rx
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.rx_i(rx_i)
     ,.rx_v_o(rx_v_lo)
     ,.rx_o(rx_data_lo)
     ,.rx_error_o(rx_error_lo)
     );
 
endmodule
