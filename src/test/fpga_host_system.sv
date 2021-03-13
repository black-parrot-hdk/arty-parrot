`include "bp_common_defines.svh"
`include "bp_me_defines.svh"
`include "bp_fpga_host_defines.svh"

module fpga_host_system
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  import bp_fpga_host_pkg::*;
  
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter nbf_addr_width_p = paddr_width_p
    , parameter nbf_data_width_p = dword_width_gp
    , localparam nbf_width_lp = `bp_fpga_host_nbf_width(nbf_addr_width_p, nbf_data_width_p)
  
    , parameter uart_clk_per_bit_p = 10416 // 100 MHz clock / 9600 Baud
    , parameter uart_data_bits_p = 8 // between 5 and 9 bits
    , parameter uart_parity_bit_p = 0 // 0 or 1
    , parameter uart_parity_odd_p = 0 // 0 for even parity, 1 for odd parity
    , parameter uart_stop_bits_p = 1 // 1 or 2
  
    , parameter io_in_nbf_buffer_els_p = 4
    , parameter io_out_nbf_buffer_els_p = 4

    , localparam putchar_base_addr_gp = paddr_width_p'(64'h0010_1000)
    
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, io)
    )
  (input sys_clk_i
   , input reset_i
   , input rx_i
   , input send_i
   , output logic tx_o
   // hooked up to a led
   , output logic error_o
   // hooked up to a led
   , output logic reset_o
   );
  
  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, io)
  // to FPGA Host
  bp_bedrock_io_mem_msg_s io_cmd_li, io_resp_lo;
  logic io_cmd_v_li, io_cmd_ready_and_lo;
  logic io_resp_v_lo, io_resp_yumi_li;
  bp_bedrock_io_mem_payload_s io_cmd_li_payload, io_resp_lo_payload;
  assign io_resp_lo_payload = io_resp_lo.header.payload;
  
  // from FPGA Host
  bp_bedrock_io_mem_msg_s io_cmd_lo, io_resp_li;
  logic io_cmd_v_lo, io_cmd_yumi_li;
  logic io_resp_v_li, io_resp_ready_and_lo;
  bp_bedrock_io_mem_payload_s io_cmd_lo_payload;
  assign io_cmd_lo_payload = io_cmd_lo.header.payload;
  
  logic [7:0] cmd_data_byte_r, cmd_data_byte_n;
  logic [7:0] resp_data_byte_r, resp_data_byte_n;
  
  wire reset_li = reset_i ? 1'b1 : 1'b0;
  assign reset_o = reset_li ? 1'b1 : 1'b0;
  
  wire send_lo = 1'b0;
  wire unused = send_i;
  // TODO:
  // logic send_lo;
  // debounce send_i
  // edge detect send_i_debounced
  
  typedef enum logic [2:0]
  {
    e_reset
    , e_ready
    , e_send
    , e_incr
    , e_resp
  } send_state_e;
  send_state_e send_state_r, send_state_n;
  
  // io loopback logic
  always_comb begin
    // from BP to FPGA host
    io_cmd_li = '0;
    io_cmd_v_li = '0;
    io_cmd_li_payload = '0;
    io_resp_yumi_li = '0;
    
    cmd_data_byte_n = cmd_data_byte_r;
    resp_data_byte_n = resp_data_byte_r;
    send_state_n = send_state_r;
    
    // from BP to FPGA Host
    unique case (send_state_r)
      e_reset: begin
        send_state_n = e_ready;
      end
      e_ready: begin
        if (send_lo) begin
          send_state_n = e_send;
        end
      end
      e_send: begin
        io_cmd_v_li = 1'b1;
        io_cmd_li.header.msg_type.mem = e_bedrock_mem_uc_wr;
        io_cmd_li.header.subop = e_bedrock_store;
        io_cmd_li.header.addr = putchar_base_addr_gp;
        io_cmd_li.data[0+:8] = cmd_data_byte_r;
        send_state_n = io_cmd_ready_and_lo ? e_incr : e_send;
      end
      e_incr: begin
        cmd_data_byte_n = cmd_data_byte_r + 'd1;
        send_state_n = e_resp;
      end
      e_resp: begin
        io_resp_yumi_li = io_resp_v_lo;
        send_state_n = io_resp_yumi_li ? e_ready : e_resp;
      end
      default: begin
        send_state_n = e_reset;
      end
    endcase
  end

  logic loopback_ready_and_lo;
  bsg_two_fifo
   #(.width_p($bits(bp_bedrock_io_mem_msg_s)))
    cmd_resp_loopback
     (.clk_i(sys_clk_i)
      ,.reset_i(reset_li)
      // from FPGA host
      ,.v_i(io_cmd_v_lo)
      ,.ready_o(loopback_ready_and_lo)
      ,.data_i(io_cmd_lo)
      // return to FPGA host
      ,.v_o(io_resp_v_li)
      ,.yumi_i(io_resp_v_li & io_resp_ready_and_lo);
      ,.data_o(io_resp_li)
      );
  assign io_cmd_yumi_li = io_cmd_v_lo & loopback_ready_and_lo;
  
  logic error_lo;
  bp_fpga_host
   #(.bp_params_p(e_bp_default_cfg)
     ,.nbf_addr_width_p(nbf_addr_width_p)
     ,.nbf_data_width_p(nbf_data_width_p)
     ,.uart_clk_per_bit_p(uart_clk_per_bit_p)
     ,.uart_data_bits_p(uart_data_bits_p)
     ,.uart_parity_bit_p(uart_parity_bit_p)
     ,.uart_parity_odd_p(uart_parity_odd_p)
     ,.uart_stop_bits_p(uart_stop_bits_p)
     ,.io_in_nbf_buffer_els_p(io_in_nbf_buffer_els_p)
     ,.io_out_nbf_buffer_els_p(io_out_nbf_buffer_els_p)
     )
    fpga_host
     (.clk_i(sys_clk_i)
      ,.reset_i(reset_li)
      // to FPGA Host
      ,.io_cmd_i(io_cmd_li)
      ,.io_cmd_v_i(io_cmd_v_li)
      ,.io_cmd_ready_and_o(io_cmd_ready_and_lo)
      ,.io_resp_o(io_resp_lo)
      ,.io_resp_v_o(io_resp_v_lo)
      ,.io_resp_yumi_i(io_resp_yumi_li)
      // from FPGA Host
      ,.io_cmd_o(io_cmd_lo)
      ,.io_cmd_v_o(io_cmd_v_lo)
      ,.io_cmd_yumi_i(io_cmd_yumi_li)
      ,.io_resp_i(io_resp_li)
      ,.io_resp_v_i(io_resp_v_li)
      ,.io_resp_ready_and_o(io_resp_ready_and_lo)
      // UART
      ,.rx_i(rx_i)
      ,.tx_o(tx_o)
      // UART error
      ,.error_o(error_lo)
      );

  assign error_o = error_lo ? 1'b1 : 1'b0;

  // sequential logic
  always_ff @(posedge sys_clk_i) begin
    if (reset_li) begin
      cmd_data_byte_r <= '0;
      resp_data_byte_r <= '0;
      send_state_r <= e_reset;
    end else begin
      cmd_data_byte_r <= cmd_data_byte_n;
      resp_data_byte_r <= resp_data_byte_n;
      send_state_r <= send_state_n;
    end
  end
  
endmodule
