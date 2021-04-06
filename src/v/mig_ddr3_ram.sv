`include "bp_fpga_wrapper_interface.svh"
`include "bp_common_defines.svh"
`include "bp_common_aviary_defines.svh"

module mig_ddr3_ram
    import bp_common_pkg::*;

    #(parameter bp_params_e bp_params_p = e_bp_default_cfg
     `declare_bp_proc_params(bp_params_p)
     `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)
      ,localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(caddr_width_p)
      )
    (input logic master_clk_100mhz_i
    ,input logic master_reset_i

    // Clock and reset (active-high) generated by the memory controller
    // All signals aside from the DDR3 control lines should be synchronized to this clock.
    ,output logic clk_o
    ,output logic rst_o

    ,`declare_mig_ddr3_native_control_ports

    ,output logic init_calib_complete_o

    ,input logic [dma_pkt_width_lp-1:0] dma_pkt_i
    ,input logic                        dma_pkt_v_i
    ,output                             dma_pkt_yumi_o

    ,output [l2_fill_width_p-1:0]       dma_data_o
    ,output                             dma_data_v_o
    ,input logic                        dma_data_ready_and_i

    ,input logic [l2_fill_width_p-1:0]  dma_data_i
    ,input logic                        dma_data_v_i
    ,output                             dma_data_yumi_o
    );


    // The below must match parameters provided to MIG
    localparam axi_id_width_p = 4;
    localparam axi_addr_width_p = 64;
    localparam axi_data_width_p = 128;
    localparam axi_burst_len_p = 4;

    logic clk_ref_lo;
    dram_clk_gen clk_gen (
      .master_clk_100mhz_i(master_clk_100mhz_i),
      .reset(master_reset_i),
      .clk_ref_o(clk_ref_lo)
    );

    wire clk_ref_li = clk_ref_lo;
    wire sys_clk_li = master_clk_100mhz_i;

    logic rst_active_low_li;
    always @(posedge clk_o) begin
        rst_active_low_li <= !rst_o;
    end

    // "Application interface" (non-AXI mode) signals we ignore
    logic mmcm_locked_lo, app_sr_active_lo, app_ref_ack_lo, app_zq_ack_lo;

    logic [3:0]  axi_awid_li;
    logic [27:0] axi_awaddr_li;
    logic [7:0]  axi_awlen_li;
    logic [2:0]  axi_awsize_li;
    logic [1:0]  axi_awburst_li;
    logic [0:0]  axi_awlock_li;
    logic [3:0]  axi_awcache_li;
    logic [2:0]  axi_awprot_li;
    logic axi_awvalid_li;
    logic axi_awready_lo;

    logic [axi_data_width_p-1:0] axi_wdata_li;
    logic [15:0]  axi_wstrb_li;
    logic axi_wlast_li;
    logic axi_wvalid_li;
    logic axi_wready_lo;

    logic [3:0] axi_bid_lo;
    logic [1:0] axi_bresp_lo;
    logic axi_bvalid_lo;
    logic axi_bready_li;

    logic [3:0]  axi_arid_li;
    logic [27:0] axi_araddr_li;
    logic [7:0]  axi_arlen_li;
    logic [2:0]  axi_arsize_li;
    logic [1:0]  axi_arburst_li;
    logic [0:0]  axi_arlock_li;
    logic [3:0]  axi_arcache_li;
    logic [2:0]  axi_arprot_li;
    logic axi_arvalid_li;
    logic axi_arready_lo;

    logic [3:0]   axi_rid_lo;
    logic [axi_data_width_p-1:0] axi_rdata_lo;
    logic [1:0]   axi_rresp_lo;
    logic axi_rlast_lo;
    logic axi_rvalid_lo;
    logic axi_rready_li;

    // Measured temperature (ADC output value) used for temperature compensation.
    // Left undriven, as the controller has been configured to own the ADC itself.
    logic [11:0] device_temp_li;

    mig_7series_0 u_mig_7series_0
        // I/O to external DDR3 chip (tied directly to top-level ports)
        (.ddr3_addr                       (ddr3_addr)
         ,.ddr3_ba                        (ddr3_ba)
         ,.ddr3_cas_n                     (ddr3_cas_n)
         ,.ddr3_ck_n                      (ddr3_ck_n)
         ,.ddr3_ck_p                      (ddr3_ck_p)
         ,.ddr3_cke                       (ddr3_cke)
         ,.ddr3_ras_n                     (ddr3_ras_n)
         ,.ddr3_we_n                      (ddr3_we_n)
         ,.ddr3_dq                        (ddr3_dq)
         ,.ddr3_dqs_n                     (ddr3_dqs_n)
         ,.ddr3_dqs_p                     (ddr3_dqs_p)
         ,.ddr3_reset_n                   (ddr3_reset_n)
         ,.init_calib_complete            (init_calib_complete_o)

         ,.ddr3_cs_n                      (ddr3_cs_n)
         ,.ddr3_dm                        (ddr3_dm)
         ,.ddr3_odt                       (ddr3_odt)

         // Application interface ports
         ,.ui_clk                         (clk_o)
         ,.ui_clk_sync_rst                (rst_o)

         ,.mmcm_locked                    (mmcm_locked_lo)

         ,.aresetn                        (rst_active_low_li)

         ,.app_sr_req                     (1'b0)
         ,.app_ref_req                    (1'b0)
         ,.app_zq_req                     (1'b0)
         ,.app_sr_active                  (app_sr_active_lo)
         ,.app_ref_ack                    (app_ref_ack_lo)
         ,.app_zq_ack                     (app_zq_ack_lo)

         // AXI Slave Interface Write Address Ports
         ,.s_axi_awid                     (axi_awid_li)
         ,.s_axi_awaddr                   (axi_awaddr_li)
         ,.s_axi_awlen                    (axi_awlen_li)
         ,.s_axi_awsize                   (axi_awsize_li)
         ,.s_axi_awburst                  (axi_awburst_li)
         ,.s_axi_awlock                   (axi_awlock_li)
         ,.s_axi_awcache                  (axi_awcache_li)
         ,.s_axi_awprot                   (axi_awprot_li)
         ,.s_axi_awqos                    (4'h0)
         ,.s_axi_awvalid                  (axi_awvalid_li)
         ,.s_axi_awready                  (axi_awready_lo)

         // AXI Slave Interface Write Data Ports
         ,.s_axi_wdata                    (axi_wdata_li)
         ,.s_axi_wstrb                    (axi_wstrb_li)
         ,.s_axi_wlast                    (axi_wlast_li)
         ,.s_axi_wvalid                   (axi_wvalid_li)
         ,.s_axi_wready                   (axi_wready_lo)

         // Slave Interface Write Response Ports
         ,.s_axi_bid                      (axi_bid_lo)
         ,.s_axi_bresp                    (axi_bresp_lo)
         ,.s_axi_bvalid                   (axi_bvalid_lo)
         ,.s_axi_bready                   (axi_bready_li)

         // AXI Slave Interface Read Address Ports
         ,.s_axi_arid                     (axi_arid_li)
         ,.s_axi_araddr                   (axi_araddr_li)
         ,.s_axi_arlen                    (axi_arlen_li)
         ,.s_axi_arsize                   (axi_arsize_li)
         ,.s_axi_arburst                  (axi_arburst_li)
         ,.s_axi_arlock                   (axi_arlock_li)
         ,.s_axi_arcache                  (axi_arcache_li)
         ,.s_axi_arprot                   (axi_arprot_li)
         ,.s_axi_arqos                    (4'h0)
         ,.s_axi_arvalid                  (axi_arvalid_li)
         ,.s_axi_arready                  (axi_arready_lo)

         // Slave Interface Read Data Ports
         ,.s_axi_rid                      (axi_rid_lo)
         ,.s_axi_rdata                    (axi_rdata_lo)
         ,.s_axi_rresp                    (axi_rresp_lo)
         ,.s_axi_rlast                    (axi_rlast_lo)
         ,.s_axi_rvalid                   (axi_rvalid_lo)
         ,.s_axi_rready                   (axi_rready_li)

         // System Clock Ports
         ,.sys_clk_i                      (sys_clk_li)

         // Reference Clock Ports
         ,.clk_ref_i                      (clk_ref_li)

         // Input measured DRAM temperature
         ,.device_temp                    (device_temp_li)

         // Input reset signal
         ,.sys_rst                        (master_reset_i)
         );

    bsg_cache_to_axi 
        #(.addr_width_p         (caddr_width_p)
          ,.block_size_in_words_p(cce_block_width_p/dword_width_gp)
          ,.data_width_p         (dword_width_gp)
          ,.num_cache_p          (1)
          ,.tag_fifo_els_p       (1)

          ,.axi_id_width_p       (axi_id_width_p)
          ,.axi_addr_width_p     (axi_addr_width_p)
          ,.axi_data_width_p     (axi_data_width_p)
          ,.axi_burst_len_p      (axi_burst_len_p)
          )
        cache_to_axi 
        (.clk_i  (clk_o)
         ,.reset_i(rst_o)

         ,.dma_pkt_i       (dma_pkt_i)
         ,.dma_pkt_v_i     (dma_pkt_v_i)
         ,.dma_pkt_yumi_o  (dma_pkt_yumi_o)

         ,.dma_data_o      (dma_data_o)
         ,.dma_data_v_o    (dma_data_v_o)
         ,.dma_data_ready_i(dma_data_ready_and_i)

         ,.dma_data_i      (dma_data_i)
         ,.dma_data_v_i    (dma_data_v_i)
         ,.dma_data_yumi_o (dma_data_yumi_o)

         ,.axi_awid_o      (axi_awid_li)
         ,.axi_awaddr_o    (axi_awaddr_li)
         ,.axi_awlen_o     (axi_awlen_li)
         ,.axi_awsize_o    (axi_awsize_li)
         ,.axi_awburst_o   (axi_awburst_li)
         ,.axi_awcache_o   (axi_awcache_li)
         ,.axi_awprot_o    (axi_awprot_li)
         ,.axi_awlock_o    (axi_awlock_li)
         ,.axi_awvalid_o   (axi_awvalid_li)
         ,.axi_awready_i   (axi_awready_lo)

         ,.axi_wdata_o     (axi_wdata_li)
         ,.axi_wstrb_o     (axi_wstrb_li)
         ,.axi_wlast_o     (axi_wlast_li)
         ,.axi_wvalid_o    (axi_wvalid_li)
         ,.axi_wready_i    (axi_wready_lo)

         ,.axi_bid_i       (axi_bid_lo)
         ,.axi_bresp_i     (axi_bresp_lo)
         ,.axi_bvalid_i    (axi_bvalid_lo)
         ,.axi_bready_o    (axi_bready_li)

         ,.axi_arid_o      (axi_arid_li)
         ,.axi_araddr_o    (axi_araddr_li)
         ,.axi_arlen_o     (axi_arlen_li)
         ,.axi_arsize_o    (axi_arsize_li)
         ,.axi_arburst_o   (axi_arburst_li)
         ,.axi_arcache_o   (axi_arcache_li)
         ,.axi_arprot_o    (axi_arprot_li)
         ,.axi_arlock_o    (axi_arlock_li)
         ,.axi_arvalid_o   (axi_arvalid_li)
         ,.axi_arready_i   (axi_arready_lo)

         ,.axi_rid_i       (axi_rid_lo)
         ,.axi_rdata_i     (axi_rdata_lo)
         ,.axi_rresp_i     (axi_rresp_lo)
         ,.axi_rlast_i     (axi_rlast_lo)
         ,.axi_rvalid_i    (axi_rvalid_lo)
         ,.axi_rready_o    (axi_rready_li)
         );

endmodule