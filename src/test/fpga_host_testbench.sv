`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/01/2021 06:31:55 PM
// Design Name: 
// Module Name: testbench
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


module testbench();

    parameter CLOCK_PERIOD_NS = 10; // 100 MHz
    parameter BAUD_RATE = 9600; // UART Baud Rate

    // max frequency is 1 GHz (due to use of NS for clock period)
    localparam clk_freq_hz = (10**9) / CLOCK_PERIOD_NS;
    localparam clk_per_bit_p = (clk_freq_hz / BAUD_RATE); // 10416 at 100MHz, 9600 Baud
    localparam ns_per_bit_p = (clk_per_bit_p * CLOCK_PERIOD_NS);

    parameter data_bits_p = 8;
    parameter parity_bit_p = 0;
    parameter stop_bits_p = 1;

    parameter test_packets_p = 10;

    bit clk = 1'b0;
    bit reset = 1'b1;
    always #(CLOCK_PERIOD_NS/2) begin
        clk = ~clk;
    end
    
    initial begin
        #200;
        reset = 1'b0;
    end
    
    // module signals
    logic tx_v_li;
    logic [data_bits_p-1:0] tx_data_li;
    logic tx_v_lo, tx_lo, tx_done_lo;
    logic rx_v_lo, rx_error_lo;
    logic [data_bits_p-1:0] rx_data_lo;

    uart_tx
        #(.clk_per_bit_p(clk_per_bit_p)
          ,.data_bits_p(data_bits_p)
          ,.parity_bit_p(parity_bit_p)
          ,.stop_bits_p(stop_bits_p)
          )
        tx
        (.clk_i(clk)
         ,.reset_i(reset)
         ,.tx_v_i(tx_v_li)
         ,.tx_i(tx_data_li)
         ,.tx_v_o(tx_v_lo)
         ,.tx_o(tx_lo)
         ,.tx_done_o(tx_done_lo)
         );

    uart_rx
        #(.clk_per_bit_p(clk_per_bit_p)
          ,.data_bits_p(data_bits_p)
          ,.parity_bit_p(parity_bit_p)
          ,.stop_bits_p(stop_bits_p)
          )
        rx
        (.clk_i(clk)
         ,.reset_i(reset)
         ,.rx_i(tx_lo)
         ,.rx_v_o(rx_v_lo)
         ,.rx_o(rx_data_lo)
         ,.rx_error_o(rx_error_lo)
         );
    
    task send_data (input [data_bits_p-1:0] data_i);
        tx_v_li = 1'b1;
        tx_data_li = data_i;
        #(CLOCK_PERIOD_NS);
        tx_v_li = 1'b0;
        tx_data_li = '0;
    endtask
    
    integer ii = 0;
    logic [data_bits_p-1:0] data_r;
    initial begin
        tx_v_li = '0;
        tx_data_li = '0;
        data_r = '0;
        #(ns_per_bit_p * 2);
        // send LSB->MSB
        for (ii = 0; ii < test_packets_p; ii = ii+1) begin
            send_data(data_r);
            @(posedge rx_v_lo);
            assert(rx_data_lo == data_r) else $error("Data mismatch!");
            data_r = data_r + 'd1;
            // TX takes some number of cycles to complete the send
            @(posedge tx_done_lo);
            #(CLOCK_PERIOD_NS);
        end
        $display("Test PASSed");
        $finish;
    end

endmodule
