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


module system
    #(parameter clk_per_bit_p = 10416 // 100 MHz clock / 9600 Baud
      , parameter data_bits_p = 8 // between 5 and 9 bits
      , parameter parity_bit_p = 0 // 0 or 1
      , parameter stop_bits_p = 1 // 1 or 2
      )
    (input sys_clk_i
    , input reset_i
    , input rx_i
    , output logic tx_o
    );
    
    wire data_v_lo;
    logic [data_bits_p-1:0] data_lo;
    
    uart_rx
        #(.clk_per_bit_p(clk_per_bit_p)
          ,.data_bits_p(data_bits_p)
          ,.parity_bit_p(parity_bit_p)
          ,.stop_bits_p(stop_bits_p)
          )
        rx
        (.clk_i(sys_clk_i)
         ,.reset_i(reset_i)
         ,.rx_i(rx_i)
         ,.rx_v_o(data_v_lo)
         ,.rx_o(data_lo)
         ,.rx_error_o()
         );
         
    uart_tx
        #(.clk_per_bit_p(clk_per_bit_p)
          ,.data_bits_p(data_bits_p)
          ,.parity_bit_p(parity_bit_p)
          ,.stop_bits_p(stop_bits_p)
          )
        tx
        (.clk_i(sys_clk_i)
         ,.reset_i(reset_i)
         ,.tx_v_i(data_v_lo)
         ,.tx_i(data_lo)
         ,.tx_v_o()
         ,.tx_o(tx_o)
         ,.tx_done_o()
         );
    
endmodule
