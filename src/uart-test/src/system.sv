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
    #(parameter clk_per_bit_p = 10416) // 100Mhz, 9600 Baud
    (input sys_clk_i
    , input reset_i
    , input rx_i
    , output logic tx_o
    );
    
    wire data_v_lo;
    logic [7:0] data_lo;
    
    uart_rx #(.clk_per_bit_p(clk_per_bit_p)) rx
        (.clk_i(sys_clk_i)
         ,.reset_i(reset_i)
         ,.rx_i(rx_i)
         ,.rx_v_o(data_v_lo)
         ,.rx_o(data_lo)
         );
         
    uart_tx #(.clk_per_bit_p(clk_per_bit_p)) tx
        (.clk_i(sys_clk_i)
         ,.reset_i(reset_i)
         ,.tx_v_i(data_v_lo)
         ,.tx_i(data_lo)
         ,.tx_v_o()
         ,.tx_o(tx_o)
         ,.tx_done_o()
         );
    
endmodule
