`include "bp_fpga_wrapper_interface.svh"
`include "bp_me_defines.svh"
`include "bp_fpga_host_defines.svh"

module wrapper
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  import bp_fpga_host_pkg::*;

    #(parameter bp_params_e bp_params_p = e_bp_unicore_l1_tiny_cfg
     `declare_bp_proc_params(bp_params_p)
      , parameter nbf_addr_width_p = paddr_width_p
      , parameter nbf_data_width_p = dword_width_gp
      , localparam nbf_width_lp = `bp_fpga_host_nbf_width(nbf_addr_width_p, nbf_data_width_p)

      , parameter uart_clk_per_bit_p = 2083 // 20MHz clock / 9600 Baud
      , parameter uart_data_bits_p = 8 // between 5 and 9 bits
      , parameter uart_parity_bit_p = 0 // 0 or 1
      , parameter uart_parity_odd_p = 0 // 0 for even parity, 1 for odd parity
      , parameter uart_stop_bits_p = 1 // 1 or 2

      , parameter io_in_nbf_buffer_els_p = 4
      , parameter io_out_nbf_buffer_els_p = 4

      , localparam putchar_base_addr_gp = paddr_width_p'(64'h0010_1000)
      , localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(caddr_width_p)

      `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, io)
      )
    (input master_clk_100mhz_i
     , input master_reset_active_low_i

     ,`declare_mig_ddr3_native_control_ports

     , input logic uart_rx_i
     , output logic uart_tx_o

     , output logic error_led_o
     , output logic reset_led_o
    );

    `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, io)

    logic fpga_host_error_lo;

    wire master_reset_async_i = !master_reset_active_low_i;
    assign reset_led_o = master_reset_async_i;
    assign error_led_o = fpga_host_error_lo;

    // Synchronizer for master clock reset
    logic reset_master_clk_lo;
    bsg_dff_chain
        #(.width_p(1)
          ,.num_stages_p(2)
        )
        reset_sync_master_clk
        (.clk_i(master_clk_100mhz_i)
         ,.data_i(master_reset_async_i)
         ,.data_o(reset_master_clk_lo)
        );

    // Clock generation
    logic reset_sys_clk_lo;
    logic sys_clk_lo, ref_clk_lo, core_clk_lo;
    assign sys_clk_lo = master_clk_100mhz_i;
    assign reset_sys_clk_lo = reset_master_clk_lo;

    // Reset generation
    // We reset the clock gen MMCM on the rising edge of the incoming reset only; this allows the
    // clock to start running again and downstream clocked modules to "see" the reset subsequently. 
    logic last_reset_sys_clk_r, clock_reset_sys_clk_r;
    always_ff @(posedge sys_clk_lo) begin
      last_reset_sys_clk_r <= reset_sys_clk_lo;
      clock_reset_sys_clk_r <= reset_sys_clk_lo && !last_reset_sys_clk_r;
    end

    dram_clk_gen clk_gen
      (.master_clk_100mhz_i(master_clk_100mhz_i)
       ,.reset(clock_reset_sys_clk_r)
       ,.ref_clk_o(ref_clk_lo)
       ,.core_clk_o(core_clk_lo)
      );

    
    // Synchronizer for core clock reset
    logic reset_core_clk_lo;
    bsg_dff_chain
        #(.width_p(1)
          ,.num_stages_p(2)
        )
        reset_sync_core_clk
        (.clk_i(core_clk_lo)
         ,.data_i(master_reset_async_i)
         ,.data_o(reset_core_clk_lo)
        );

    // I/O command buses
    // to FPGA Host
    bp_bedrock_io_mem_msg_s fpga_host_io_cmd_li, fpga_host_io_resp_lo;
    logic fpga_host_io_cmd_v_li, fpga_host_io_cmd_ready_and_lo;
    logic fpga_host_io_resp_v_lo, fpga_host_io_resp_yumi_li;
    
    // from FPGA Host
    bp_bedrock_io_mem_msg_s fpga_host_io_cmd_lo, fpga_host_io_resp_li;
    logic fpga_host_io_cmd_v_lo, fpga_host_io_cmd_yumi_li;
    logic fpga_host_io_resp_v_li, fpga_host_io_resp_ready_and_lo;


    // bsg cache DRAM buses
    logic [dma_pkt_width_lp-1:0] dram_controller_dma_pkt_li;
    logic                        dram_controller_dma_pkt_v_li;
    logic                        dram_controller_dma_pkt_yumi_lo;

    logic[l2_fill_width_p-1:0]   dram_controller_dma_data_lo;
    logic                        dram_controller_dma_data_v_lo;
    logic                        dram_controller_dma_data_ready_and_li;

    logic [l2_fill_width_p-1:0]  dram_controller_dma_data_li;
    logic                        dram_controller_dma_data_v_li;
    logic                        dram_controller_dma_data_yumi_lo;

    // DRAM controller
    logic init_calib_complete_lo;
    mig_ddr3_ram
        #(.bp_params_p(bp_params_p))
        dram_controller
        (.sys_clk_i(sys_clk_lo)
         ,.reset_sys_clk_i(reset_sys_clk_lo)
         ,.ref_clk_i(ref_clk_lo)
         ,.core_clk_i(core_clk_lo)
         ,.reset_core_clk_i(reset_core_clk_lo)

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

         ,.ddr3_odt      (ddr3_odt)

         ,.init_calib_complete_o(init_calib_complete_lo)

         // BP core memory interface
         ,.dma_pkt_i            (dram_controller_dma_pkt_li)
         ,.dma_pkt_v_i          (dram_controller_dma_pkt_v_li)
         ,.dma_pkt_yumi_o       (dram_controller_dma_pkt_yumi_lo)

         ,.dma_data_o           (dram_controller_dma_data_lo)
         ,.dma_data_v_o         (dram_controller_dma_data_v_lo)
         ,.dma_data_ready_and_i (dram_controller_dma_data_ready_and_li)

         ,.dma_data_i           (dram_controller_dma_data_li)
         ,.dma_data_v_i         (dram_controller_dma_data_v_li)
         ,.dma_data_yumi_o      (dram_controller_dma_data_yumi_lo)
         );


    // FPGA Host
    bp_fpga_host
      #(.bp_params_p              (bp_params_p)
        ,.nbf_addr_width_p        (nbf_addr_width_p)
        ,.nbf_data_width_p        (nbf_data_width_p)
        ,.uart_clk_per_bit_p      (uart_clk_per_bit_p)
        ,.uart_data_bits_p        (uart_data_bits_p)
        ,.uart_parity_bit_p       (uart_parity_bit_p)
        ,.uart_parity_odd_p       (uart_parity_odd_p)
        ,.uart_stop_bits_p        (uart_stop_bits_p)
        ,.io_in_nbf_buffer_els_p  (io_in_nbf_buffer_els_p)
        ,.io_out_nbf_buffer_els_p (io_out_nbf_buffer_els_p)
        )
        fpga_host
        (.clk_i(core_clk_lo)
         ,.reset_i(reset_core_clk_lo)

         // to FPGA Host
         ,.io_cmd_i           (fpga_host_io_cmd_li)
         ,.io_cmd_v_i         (fpga_host_io_cmd_v_li)
         ,.io_cmd_ready_and_o (fpga_host_io_cmd_ready_and_lo)

         ,.io_resp_o          (fpga_host_io_resp_lo)
         ,.io_resp_v_o        (fpga_host_io_resp_v_lo)
         ,.io_resp_yumi_i     (fpga_host_io_resp_yumi_li)

         // from FPGA Host
         ,.io_cmd_o            (fpga_host_io_cmd_lo)
         ,.io_cmd_v_o          (fpga_host_io_cmd_v_lo)
         ,.io_cmd_yumi_i       (fpga_host_io_cmd_yumi_li)

         ,.io_resp_i           (fpga_host_io_resp_li)
         ,.io_resp_v_i         (fpga_host_io_resp_v_li)
         ,.io_resp_ready_and_o (fpga_host_io_resp_ready_and_lo)

         // UART
         ,.rx_i(uart_rx_i)
         ,.tx_o(uart_tx_o)

         // UART error
         ,.error_o(fpga_host_error_lo)
        );


    // Black Parrot core
    bp_unicore
      #(.bp_params_p(bp_params_p))
      core
      (.clk_i(core_clk_lo)
       ,.reset_i(reset_core_clk_lo)

       // I/O to FPGA Host
       ,.io_cmd_o        (fpga_host_io_cmd_li)
       ,.io_cmd_v_o      (fpga_host_io_cmd_v_li)
       ,.io_cmd_ready_and_i  (fpga_host_io_cmd_ready_and_lo)

       ,.io_resp_i       (fpga_host_io_resp_lo)
       ,.io_resp_v_i     (fpga_host_io_resp_v_lo)
       ,.io_resp_yumi_o  (fpga_host_io_resp_yumi_li)

       // I/O from FPGA host
       ,.io_cmd_i        (fpga_host_io_cmd_lo)
       ,.io_cmd_v_i      (fpga_host_io_cmd_v_lo)
       ,.io_cmd_yumi_o   (fpga_host_io_cmd_yumi_li)

       ,.io_resp_o       (fpga_host_io_resp_li)
       ,.io_resp_v_o     (fpga_host_io_resp_v_li)
       ,.io_resp_ready_and_i (fpga_host_io_resp_ready_and_lo)

       // DRAM interface
       ,.dma_pkt_o      (dram_controller_dma_pkt_li)
       ,.dma_pkt_v_o    (dram_controller_dma_pkt_v_li)
       ,.dma_pkt_yumi_i (dram_controller_dma_pkt_yumi_lo)

       ,.dma_data_i           (dram_controller_dma_data_lo)
       ,.dma_data_v_i         (dram_controller_dma_data_v_lo)
       ,.dma_data_ready_and_o (dram_controller_dma_data_ready_and_li)

       ,.dma_data_o      (dram_controller_dma_data_li)
       ,.dma_data_v_o    (dram_controller_dma_data_v_li)
       ,.dma_data_yumi_i (dram_controller_dma_data_yumi_lo)
      );

endmodule