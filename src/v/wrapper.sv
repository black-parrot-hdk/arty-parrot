`include "bp_fpga_wrapper_interface.svh"

module wrapper
  import bp_common_pkg::*;

    #(parameter bp_params_e bp_params_p = e_bp_unicore_l1_tiny_cfg
     `declare_bp_proc_params(bp_params_p)
     `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)
      )
    (`declare_mig_ddr3_native_control_ports
     , input rx_i
     , input send_i
     , output logic tx_o
     , output logic error_led_o
     , output logic reset_led_o
    );

    localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(caddr_width_p);

    // Top-level clock, generated by the RAM controller (to avoid multiple clocks)
    logic clock;
    logic reset_lo;
    
    assign reset_led_o = reset_lo;

    // DRAM interface
    // port directions are from the perspective of the memory module
    logic [dma_pkt_width_lp-1:0] dram_dma_pkt_li;
    logic                        dram_dma_pkt_v_li;
    logic                        dram_dma_pkt_yumi_lo;

    logic[l2_fill_width_p-1:0]   dram_dma_data_lo;
    logic                        dram_dma_data_v_lo;
    logic                        dram_dma_data_ready_and_li;

    logic [l2_fill_width_p-1:0]  dram_dma_data_li;
    logic                        dram_dma_data_v_li;
    logic                        dram_dma_data_yumi_lo;

    ram
        #(.bp_params_p(bp_params_p))
        dram
        (.clk_o(clock)
         ,.rst_o(reset_lo)

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

         ,.sys_clk_i    (sys_clk_i)
         ,.clk_ref_i    (clk_ref_i)

         ,.tg_compare_error    (tg_compare_error)
         ,.init_calib_complete (init_calib_complete)

         ,.sys_rst      (sys_rst)

         // BP core memory interface
         ,.dma_pkt_i            (dma_pkt_i)
         ,.dma_pkt_v_i          (dma_pkt_v_i)
         ,.dma_pkt_yumi_o       (dma_pkt_yumi_o)

         ,.dma_data_o           (dma_data_o)
         ,.dma_data_v_o         (dma_data_v_o)
         ,.dma_data_ready_and_i (dma_data_ready_and_i)

         ,.dma_data_i           (dma_data_i)
         ,.dma_data_v_i         (dma_data_v_i)
         ,.dma_data_yumi_o      (dma_data_yumi_o)
         );

endmodule