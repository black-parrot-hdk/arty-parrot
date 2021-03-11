`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/01/2021 11:17:55 AM
// Design Name: 
// Module Name: system
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"
`include "bp_fpga_host_defines.svh"

module system
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
    
    , localparam reset_cycles_lp = 16384
    , localparam reset_cnt_width_lp = `BSG_SAFE_CLOG2(reset_cycles_lp)
    
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, io)
    )
  (input sys_clk_i
   // hooked up to button
   , input reset_i
   , input rx_i
   , input send_i
   , output logic tx_o
   , output logic error_o
   // hooked up to reset_r
   , output logic led_o
   );
  
  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, io)
  // to FPGA Host
  bp_bedrock_io_mem_msg_s io_cmd_li, io_resp_lo;
  logic io_cmd_v_li, io_cmd_ready_and_lo;
  logic io_resp_v_lo, io_resp_yumi_li;
  bp_bedrock_io_mem_msg_payload_s io_cmd_li_payload, io_resp_lo_payload;
  assign io_resp_lo_payload = io_resp.header.payload;
  
  // from FPGA Host
  bp_bedrock_io_mem_msg_s io_cmd_lo, io_resp_li;
  logic io_cmd_v_lo, io_cmd_yumi_li;
  logic io_resp_v_li, io_resp_ready_and_lo;
  bp_bedrock_io_mem_msg_payload_s io_cmd_lo_payload, io_resp_li_payload;
  assign io_cmd_lo_payload = io_cmd.header.payload;
  
  logic [7:0] data_byte_r, data_byte_n;
  
  typedef enum logic [2:0]
  {
    e_reset
    , e_send
    , e_incr
  } send_state_e;
  send_state_e send_state_r, send_state_n;
  
  // io loopback logic
  always_comb begin
    io_cmd_li = '0;
    io_cmd_v_li = '0;
    io_cmd_li_payload = '0;
    io_resp_yumi_li = '0;
    
    io_resp_li = '0;
    io_resp_v_li = '0;
    io_resp_li_payload = '0;
    io_cmd_yumi_li = '0;
    
    data_byte_n = data_byte_r;
    send_state_n = send_state_r;
    
    // from FPGA Host to BP
    if (io_cmd_v_lo) begin
      io_resp_li = io_cmd_lo;
      if (io_cmd_lo.header.msg_type.mem == e_bedrock_mem_uc_rd) begin
        io_resp_li.data[0+:8] = data_byte_r;
      end
      io_resp_v_li = 1'b1;
      io_cmd_yumi_li = io_cmd_v_lo & io_resp_ready_and_lo;
    end
    
    // from BP to FPGA Host
    unique case (send_state_r)
      e_reset: begin
        state_n = e_send;
      end
      e_send: begin
      end
      e_incr: begin
      end
      default: begin
        state_n = e_reset;
      end
    endcase
  end
  
  bp_fpga_host
   #(.bp_params_p(e_bp_default_cfg)
     )
    fpga_host
     (.clk_i(sys_clk_i)
      ,.reset_i(reset_r)
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
      ,.io_resp_v_i(io_rsp_v_li)
      ,.io_resp_ready_and_o(io_resp_ready_and_lo)
      ,.rx_i(rx_i)
      ,.tx_o(tx_o)
      ,.error_o(error_o)
      );

  // sequential logic
  logic reset_r, reset_n;
  logic [reset_cnt_width_lp-1:0] reset_cnt_r, reset_cnt_n;
  assign led_o = reset_r;
  always_ff @(posedge sys_clk_i) begin
    if (reset_i) begin
      reset_r <= 1'b1;
      reset_cnt_r <= '0;
      data_byte_r <= '0;
      send_state_r <= e_reset;
    end else begin
      reset_r <= reset_n;
      reset_cnt_r <= reset_cnt_n;
      data_byte_r <= data_byte_n;
      send_state_r <= send_state_n;
    end
  end
  
  // reset combinational logic
  always_comb begin
    if (reset_cnt_r < reset_cycles_lp-1) begin
      reset_cnt_r <= reset_cnt_n + 'd1;
    end else begin
      reset_r <= 1'b0;
    end
  end
  
endmodule
