`timescale 1ns / 1ps

`include "bp_common_defines.svh"
`include "bp_common_aviary_defines.svh"
`include "bp_fpga_host_defines.svh"

module wrapper_testbench
    import bp_common_pkg::*;
    import bsg_cache_pkg::*;
  import bp_fpga_host_pkg::*;

    #(parameter bp_params_e bp_params_p = e_bp_unicore_l1_tiny_cfg
      `declare_bp_proc_params(bp_params_p)
      `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)

      , parameter nbf_addr_width_p = paddr_width_p
      , parameter nbf_data_width_p = dword_width_gp
      , localparam nbf_width_lp = `bp_fpga_host_nbf_width(nbf_addr_width_p, nbf_data_width_p)

      // Use artificially fast baud for simulation
      // Entire DUT system is running on a downsampled clock, while our testbench runs on the 100MHz master clock
      , parameter uart_100mhz_clk_per_bit_p = 10 // 100 MHz clock / 10_000_000 Baud
      , parameter uart_memory_clk_per_bit_p = 5 // 50MHz clock / 9600 Baud
      , parameter uart_data_bits_p = 8 // between 5 and 9 bits
      , parameter uart_parity_bit_p = 0 // 0 or 1
      , parameter uart_parity_odd_p = 0 // 0 for even parity, 1 for odd parity
      , parameter uart_stop_bits_p = 1 // 1 or 2
      )
    ();

    `declare_bp_fpga_host_nbf_s(nbf_addr_width_p, nbf_data_width_p);

    localparam MASTER_CLOCK_PERIOD_NS = 10;
    localparam reset_clks_p = 64;

    wire [15:0]  ddr3_dq;
    wire [1:0]   ddr3_dqs_n;
    wire [1:0]   ddr3_dqs_p;

    logic [13:0] ddr3_addr;
    logic [2:0]  ddr3_ba;
    logic        ddr3_ras_n;
    logic        ddr3_cas_n;
    logic        ddr3_we_n;
    logic        ddr3_reset_n;
    logic [0:0]  ddr3_ck_p;
    logic [0:0]  ddr3_ck_n;
    logic [0:0]  ddr3_cke;

    logic [0:0]  ddr3_cs_n;
    wire [1:0]   ddr3_dm;
    logic [0:0]  ddr3_odt;

    logic reset_led_lo;
    logic error_led_lo;

    // Master clock and reset
    bit master_clk_100mhz_i;
    bsg_nonsynth_clock_gen
        #(.cycle_time_p(MASTER_CLOCK_PERIOD_NS*1000 /* picoseconds */))
        clock_gen_sys_clk
        (.o(master_clk_100mhz_i));

    bit master_reset_i;
    bsg_nonsynth_reset_gen
        #(.num_clocks_p(1)
          ,.reset_cycles_lo_p(0)
          ,.reset_cycles_hi_p(reset_clks_p)
        )
        reset_gen
        (.clk_i(master_clk_100mhz_i)
         ,.async_reset_o(master_reset_i)
        );
    wire master_reset_active_low_i = !master_reset_i;

    logic device_uart_rx_li, device_uart_tx_lo;
    wrapper
        #(.bp_params_p(bp_params_p)
          ,.uart_clk_per_bit_p(uart_memory_clk_per_bit_p)
          )
        dut
        (.master_clk_100mhz_i(master_clk_100mhz_i)
         ,.master_reset_active_low_i(master_reset_active_low_i)

         ,.reset_led_o(reset_led_lo)
         ,.error_led_o(error_led_lo)

         ,.uart_rx_i (device_uart_rx_li)
         ,.uart_tx_o (device_uart_tx_lo)

         // DDR3 control signals and other direct pass-through
         ,.ddr3_dq      (ddr3_dq)
         ,.ddr3_dqs_n   (ddr3_dqs_n)
         ,.ddr3_dqs_p   (ddr3_dqs_p)

         ,.ddr3_addr    (ddr3_addr)
         ,.ddr3_ba      (ddr3_ba)
         ,.ddr3_ras_n   (ddr3_ras_n)
         ,.ddr3_cas_n   (ddr3_cas_n)
         ,.ddr3_we_n    (ddr3_we_n)
         ,.ddr3_reset_n (ddr3_reset_n)
         ,.ddr3_ck_p    (ddr3_ck_p)
         ,.ddr3_ck_n    (ddr3_ck_n)
         ,.ddr3_cke     (ddr3_cke)

         ,.ddr3_cs_n    (ddr3_cs_n)

         ,.ddr3_dm      (ddr3_dm)

         ,.ddr3_odt     (ddr3_odt)
        );

    logic host_rx_v_lo, host_rx_error_lo;
    logic [uart_data_bits_p-1:0] host_rx_data_lo;
    uart_rx
    #(.clk_per_bit_p(uart_100mhz_clk_per_bit_p)
      ,.data_bits_p(uart_data_bits_p)
      ,.parity_bit_p(uart_parity_bit_p)
      ,.stop_bits_p(uart_stop_bits_p)
      ,.parity_odd_p(uart_parity_odd_p)
      )
      rx
      (.clk_i(master_clk_100mhz_i)
      ,.reset_i(master_reset_i)
      // from PC / UART pin
      ,.rx_i(device_uart_tx_lo)
      // controlled by testbench
      ,.rx_v_o(host_rx_v_lo)
      ,.rx_o(host_rx_data_lo)
      // error signal
      ,.rx_error_o(host_rx_error_lo)
      );

    // UART TX
    logic [uart_data_bits_p-1:0] host_tx_data_li;
    logic host_tx_v_li, host_tx_ready_and_lo, host_tx_v_lo, host_tx_done_lo;
    uart_tx
    #(.clk_per_bit_p(uart_100mhz_clk_per_bit_p)
      ,.data_bits_p(uart_data_bits_p)
      ,.parity_bit_p(uart_parity_bit_p)
      ,.stop_bits_p(uart_stop_bits_p)
      ,.parity_odd_p(uart_parity_odd_p)
      )
      tx
      (.clk_i(master_clk_100mhz_i)
      ,.reset_i(master_reset_i)
      // input
      ,.tx_v_i(host_tx_v_li)
      ,.tx_i(host_tx_data_li)
      ,.tx_ready_and_o(host_tx_ready_and_lo)
      // output
      ,.tx_v_o(host_tx_v_lo)
      ,.tx_o(device_uart_rx_li)
      ,.tx_done_o(host_tx_done_lo)
      );

    ddr3_model fake_ddr3_chip
        (.rst_n   (ddr3_reset_n)
         ,.ck      (ddr3_ck_p)
         ,.ck_n    (ddr3_ck_n)
         ,.cke     (ddr3_cke)
         ,.cs_n    (ddr3_cs_n)
         ,.ras_n   (ddr3_ras_n)
         ,.cas_n   (ddr3_cas_n)
         ,.we_n    (ddr3_we_n)
         ,.dm_tdqs (ddr3_dm)
         ,.ba      (ddr3_ba)
         ,.addr    (ddr3_addr)
         ,.dq      (ddr3_dq)
         ,.dqs     (ddr3_dqs_p)
         ,.dqs_n   (ddr3_dqs_n)
         ,.tdqs_n  ()
         ,.odt     (ddr3_odt)
        );

    wire clk = master_clk_100mhz_i;
    wire reset = master_reset_i; 

    integer jj = 0;
    task send_nbf (input bp_fpga_host_nbf_s nbf_i);
      for (jj = 0; jj < 14; jj = jj+1) begin
        @(posedge clk);
        host_tx_data_li = nbf_i[8*jj+:8];
        host_tx_v_li = 1'b1;
        do @(posedge clk); while (!host_tx_ready_and_lo);
        host_tx_v_li = 1'b0;
        host_tx_data_li = '0;
        @(posedge clk);
      end
    endtask

    integer kk = 0;
    task read_nbf (output bp_fpga_host_nbf_s nbf_o);
      nbf_o = '0;
      for (kk = 0; kk < 14; kk = kk+1) begin
        @(posedge host_rx_v_lo);
        nbf_o[8*kk+:8] = host_rx_data_lo;
      end
    endtask

    integer ii = 0;
    bp_fpga_host_nbf_s nbf_in, nbf_out;
    initial begin
        host_tx_v_li = '0;
        host_tx_data_li = '0;
        nbf_in = '0;

        // Wait long enough for the DRAM controller to signal the internal reset
        @(posedge reset);
        #2000;
        @(posedge clk);

        // Write some data into memory
        nbf_in = '0;
        nbf_in.opcode = e_fpga_host_nbf_write_8;
        nbf_in.data[0+:8] = 8'hAB;
        nbf_in.addr = 39'h00_8000_0000;
        send_nbf(nbf_in);
        // response should be an ack
        read_nbf(nbf_out);
        assert(nbf_out.opcode == nbf_in.opcode) else $error("Write ack opcode mismatch!");
        assert(nbf_out.addr == nbf_in.addr) else $error("Write ack addr mismatch!");
        assert(nbf_out.data[0+:8] == 8'b0) else $error("Write ack data mismatch!");

        // Read the data from above back out
        nbf_in = '0;
        nbf_in.opcode = e_fpga_host_nbf_read_8;
        nbf_in.addr = 39'h00_8000_0000;
        send_nbf(nbf_in);
        read_nbf(nbf_out);
        assert(nbf_out.data[0+:8] == 8'hAB) else $error("Read data mismatch!");
    end
endmodule