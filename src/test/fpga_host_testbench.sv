`timescale 1ns / 1ps

`include "bp_fpga_host_defines.svh"

module fpga_host_testbench
  import bp_fpga_host_pkg::*;
  #()
  ();

  parameter CLOCK_PERIOD_NS = 10; // 100 MHz
  parameter BAUD_RATE = 9600; // UART Baud Rate

  // max frequency is 1 GHz (due to use of NS for clock period)
  localparam clk_freq_hz = (10**9) / CLOCK_PERIOD_NS;
  localparam clk_per_bit_p = (clk_freq_hz / BAUD_RATE); // 10416 at 100MHz, 9600 Baud
  localparam ns_per_bit_p = (clk_per_bit_p * CLOCK_PERIOD_NS);

  parameter reset_clks_p = 16384+2;

  parameter nbf_addr_width_p = 40;
  parameter nbf_data_width_p = 64;

  parameter uart_clk_per_bit_p = clk_per_bit_p; // 100 MHz clock / 9600 Baud
  parameter uart_data_bits_p = 8; // between 5 and 9 bits
  parameter uart_parity_bit_p = 0; // 0 or 1
  parameter uart_parity_odd_p = 0; // 0 for even parity, 1 for odd parity
  parameter uart_stop_bits_p = 1; // 1 or 2

  parameter io_in_nbf_buffer_els_p = 4;
  parameter io_out_nbf_buffer_els_p = 4;
  
  parameter test_packets_p = 2;

  `declare_bp_fpga_host_nbf_s(nbf_addr_width_p, nbf_data_width_p);

  bit clk = 1'b0;
  bit reset = 1'b1;
  always #(CLOCK_PERIOD_NS/2) begin
      clk = ~clk;
  end
  
  initial begin
      #(reset_clks_p);
      reset = 1'b0;
  end
    
  // module signals
  logic tx_lo, rx_li; 
  logic reset_lo, error_lo;
  
  fpga_host_system
      #(.nbf_addr_width_p(nbf_addr_width_p)
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
      (.sys_clk_i(clk)
       ,.reset_i(reset)
       ,.rx_i(rx_li)
       ,.tx_o(tx_lo)
       ,.send_i('0)
       ,.error_o(error_lo)
       ,.reset_o(reset_lo)
       );
    
  logic rx_v_lo, rx_error_lo;
  logic [uart_data_bits_p-1:0] rx_data_lo;
  uart_rx
   #(.clk_per_bit_p(uart_clk_per_bit_p)
     ,.data_bits_p(uart_data_bits_p)
     ,.parity_bit_p(uart_parity_bit_p)
     ,.stop_bits_p(uart_stop_bits_p)
     ,.parity_odd_p(uart_parity_odd_p)
     )
    rx
    (.clk_i(clk)
     ,.reset_i(reset)
     // from PC / UART pin
     ,.rx_i(tx_lo)
     // to nbf_sipo
     ,.rx_v_o(rx_v_lo)
     ,.rx_o(rx_data_lo)
     // error signal
     ,.rx_error_o(rx_error_lo)
     );

  // UART TX
  logic [uart_data_bits_p-1:0] tx_data_li;
  logic tx_v_li, tx_ready_and_lo, tx_v_lo, tx_done_lo;
  uart_tx
   #(.clk_per_bit_p(uart_clk_per_bit_p)
     ,.data_bits_p(uart_data_bits_p)
     ,.parity_bit_p(uart_parity_bit_p)
     ,.stop_bits_p(uart_stop_bits_p)
     ,.parity_odd_p(uart_parity_odd_p)
     )
    tx
    (.clk_i(clk)
     ,.reset_i(reset)
     // input
     ,.tx_v_i(tx_v_li)
     ,.tx_i(tx_data_li)
     ,.tx_ready_and_o(tx_ready_and_lo)
     // output
     ,.tx_v_o(tx_v_lo)
     ,.tx_o(rx_li)
     ,.tx_done_o(tx_done_lo)
     );

    integer jj = 0;
    task send_nbf (input bp_fpga_host_nbf_s nbf_i);
      for (jj = 0; jj < 14; jj = jj+1) begin
        // start send on posedge clk
        @(posedge clk)
        tx_data_li = nbf_i[8*jj+:8];
        wait(tx_ready_and_lo == 1'b1);
        tx_v_li = 1'b1;
        #(CLOCK_PERIOD_NS);
        #(CLOCK_PERIOD_NS/2);
        tx_v_li = 1'b0;
        tx_data_li = '0;
        #(CLOCK_PERIOD_NS/2);
      end
    endtask
    
    integer kk = 0;
    task read_nbf (output bp_fpga_host_nbf_s nbf_o);
      nbf_o = '0;
      for (kk = 0; kk < 14; kk = kk+1) begin
        @(posedge rx_v_lo);
        nbf_o[8*kk+:8] = rx_data_lo;
      end
    endtask
    
    integer ii = 0;
    bp_fpga_host_nbf_s nbf_in, nbf_out;
    initial begin
        tx_v_li = '0;
        tx_data_li = '0;
        nbf_in = '0;
        nbf_in.opcode = e_fpga_host_nbf_finish;
        #(reset_clks_p * 2);
        // send LSB->MSB
        for (ii = 0; ii < test_packets_p; ii = ii+1) begin
            send_nbf(nbf_in);
            read_nbf(nbf_out);
            assert(nbf_out == nbf_in) else $error("Data mismatch!");
            #(CLOCK_PERIOD_NS);
        end
        $display("Test PASSed");
        $finish;
    end

endmodule
