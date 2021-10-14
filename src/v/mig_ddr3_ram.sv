`include "bp_mig_ddr3_ram_interface.svh"
`include "bp_common_defines.svh"
`include "bp_common_aviary_defines.svh"

module mig_ddr3_ram
    import bp_common_pkg::*;

    #(parameter bp_params_e bp_params_p = e_bp_default_cfg
     `declare_bp_proc_params(bp_params_p)
     `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)
      ,localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(caddr_width_p)
      )
    // 100MHz primary clock, used only for RAM
    (input logic sys_clk_i
    ,input logic reset_sys_clk_i
    // 200MHz reference clock, used only for RAM
    ,input logic ref_clk_i
    // lower-frequency clock, used for the core and all I/O
    // ALL PORTS are synchronized to this clock
    ,input logic core_clk_i
    ,input logic reset_core_clk_i

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
    // TODO: Memory addresses are truncated to 28 bits, which implicitly handles the
    // offset from 0x8000_0000. Explicitly apply this offset instead.
    localparam axi_addr_width_p = 28;
    localparam axi_data_width_p = 128;
    localparam axi_burst_len_p = 4;

    logic ui_clk_lo, reset_ui_clk_lo;
    logic reset_ui_clk_active_low_li;
    always @(posedge ui_clk_lo) begin
        reset_ui_clk_active_low_li <= !reset_ui_clk_lo;
    end

    wire reset_core_clk_active_low_li = !reset_core_clk_i;

    logic init_calib_complete_ui_clk_lo;
    bsg_dff_chain
        #(.width_p(1)
          ,.num_stages_p(2)
        )
        calib_complete_sync
        (.clk_i(core_clk_i)
         ,.data_i(init_calib_complete_ui_clk_lo)
         ,.data_o(init_calib_complete_o)
        );

    // "Application interface" (non-AXI mode) signals we ignore
    logic mmcm_locked_lo, app_sr_active_lo, app_ref_ack_lo, app_zq_ack_lo;

    // AXI bus from cache DMA translator to clock domain crossing
    logic [3:0]  axi_awid_core_clk_li;
    logic [27:0] axi_awaddr_core_clk_li;
    logic [7:0]  axi_awlen_core_clk_li;
    logic [2:0]  axi_awsize_core_clk_li;
    logic [1:0]  axi_awburst_core_clk_li;
    logic [0:0]  axi_awlock_core_clk_li;
    logic [3:0]  axi_awcache_core_clk_li;
    logic [2:0]  axi_awprot_core_clk_li;
    logic axi_awvalid_core_clk_li;
    logic axi_awready_core_clk_lo;

    logic [axi_data_width_p-1:0] axi_wdata_core_clk_li;
    logic [15:0]  axi_wstrb_core_clk_li;
    logic axi_wlast_core_clk_li;
    logic axi_wvalid_core_clk_li;
    logic axi_wready_core_clk_lo;

    logic [3:0] axi_bid_core_clk_lo;
    logic [1:0] axi_bresp_core_clk_lo;
    logic axi_bvalid_core_clk_lo;
    logic axi_bready_core_clk_li;

    logic [3:0]  axi_arid_core_clk_li;
    logic [27:0] axi_araddr_core_clk_li;
    logic [7:0]  axi_arlen_core_clk_li;
    logic [2:0]  axi_arsize_core_clk_li;
    logic [1:0]  axi_arburst_core_clk_li;
    logic [0:0]  axi_arlock_core_clk_li;
    logic [3:0]  axi_arcache_core_clk_li;
    logic [2:0]  axi_arprot_core_clk_li;
    logic axi_arvalid_core_clk_li;
    logic axi_arready_core_clk_lo;

    logic [3:0]   axi_rid_core_clk_lo;
    logic [axi_data_width_p-1:0] axi_rdata_core_clk_lo;
    logic [1:0]   axi_rresp_core_clk_lo;
    logic axi_rlast_core_clk_lo;
    logic axi_rvalid_core_clk_lo;
    logic axi_rready_core_clk_li;

    // Ignored signals
    logic [3:0] axi_arqos_core_clk_li, axi_awqos_core_clk_li;
    logic [3:0] axi_arregion_core_clk_li, axi_awregion_core_clk_li;

    // AXI bus from clock domain crossing to DRAM
    logic [3:0]  axi_awid_ui_clk_li;
    logic [27:0] axi_awaddr_ui_clk_li;
    logic [7:0]  axi_awlen_ui_clk_li;
    logic [2:0]  axi_awsize_ui_clk_li;
    logic [1:0]  axi_awburst_ui_clk_li;
    logic [0:0]  axi_awlock_ui_clk_li;
    logic [3:0]  axi_awcache_ui_clk_li;
    logic [2:0]  axi_awprot_ui_clk_li;
    logic axi_awvalid_ui_clk_li;
    logic axi_awready_ui_clk_lo;

    logic [axi_data_width_p-1:0] axi_wdata_ui_clk_li;
    logic [15:0]  axi_wstrb_ui_clk_li;
    logic axi_wlast_ui_clk_li;
    logic axi_wvalid_ui_clk_li;
    logic axi_wready_ui_clk_lo;

    logic [3:0] axi_bid_ui_clk_lo;
    logic [1:0] axi_bresp_ui_clk_lo;
    logic axi_bvalid_ui_clk_lo;
    logic axi_bready_ui_clk_li;

    logic [3:0]  axi_arid_ui_clk_li;
    logic [27:0] axi_araddr_ui_clk_li;
    logic [7:0]  axi_arlen_ui_clk_li;
    logic [2:0]  axi_arsize_ui_clk_li;
    logic [1:0]  axi_arburst_ui_clk_li;
    logic [0:0]  axi_arlock_ui_clk_li;
    logic [3:0]  axi_arcache_ui_clk_li;
    logic [2:0]  axi_arprot_ui_clk_li;
    logic axi_arvalid_ui_clk_li;
    logic axi_arready_ui_clk_lo;

    logic [3:0]   axi_rid_ui_clk_lo;
    logic [axi_data_width_p-1:0] axi_rdata_ui_clk_lo;
    logic [1:0]   axi_rresp_ui_clk_lo;
    logic axi_rlast_ui_clk_lo;
    logic axi_rvalid_ui_clk_lo;
    logic axi_rready_ui_clk_li;

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
         ,.init_calib_complete            (init_calib_complete_ui_clk_lo)

         ,.ddr3_cs_n                      (ddr3_cs_n)
         ,.ddr3_dm                        (ddr3_dm)
         ,.ddr3_odt                       (ddr3_odt)

         // Application interface ports
         ,.ui_clk                         (ui_clk_lo)
         ,.ui_clk_sync_rst                (reset_ui_clk_lo)

         ,.mmcm_locked                    (mmcm_locked_lo)

         ,.aresetn                        (reset_ui_clk_active_low_li)

         ,.app_sr_req                     (1'b0)
         ,.app_ref_req                    (1'b0)
         ,.app_zq_req                     (1'b0)
         ,.app_sr_active                  (app_sr_active_lo)
         ,.app_ref_ack                    (app_ref_ack_lo)
         ,.app_zq_ack                     (app_zq_ack_lo)

         // AXI S Interface Write Address Ports
         ,.s_axi_awid                     (axi_awid_ui_clk_li)
         ,.s_axi_awaddr                   (axi_awaddr_ui_clk_li)
         ,.s_axi_awlen                    (axi_awlen_ui_clk_li)
         ,.s_axi_awsize                   (axi_awsize_ui_clk_li)
         ,.s_axi_awburst                  (axi_awburst_ui_clk_li)
         ,.s_axi_awlock                   (axi_awlock_ui_clk_li)
         ,.s_axi_awcache                  (axi_awcache_ui_clk_li)
         ,.s_axi_awprot                   (axi_awprot_ui_clk_li)
         ,.s_axi_awqos                    (4'h0)
         ,.s_axi_awvalid                  (axi_awvalid_ui_clk_li)
         ,.s_axi_awready                  (axi_awready_ui_clk_lo)

         // AXI S Interface Write Data Ports
         ,.s_axi_wdata                    (axi_wdata_ui_clk_li)
         ,.s_axi_wstrb                    (axi_wstrb_ui_clk_li)
         ,.s_axi_wlast                    (axi_wlast_ui_clk_li)
         ,.s_axi_wvalid                   (axi_wvalid_ui_clk_li)
         ,.s_axi_wready                   (axi_wready_ui_clk_lo)

         // AXI S Interface Write Response Ports
         ,.s_axi_bid                      (axi_bid_ui_clk_lo)
         ,.s_axi_bresp                    (axi_bresp_ui_clk_lo)
         ,.s_axi_bvalid                   (axi_bvalid_ui_clk_lo)
         ,.s_axi_bready                   (axi_bready_ui_clk_li)

         // AXI S Interface Read Address Ports
         ,.s_axi_arid                     (axi_arid_ui_clk_li)
         ,.s_axi_araddr                   (axi_araddr_ui_clk_li)
         ,.s_axi_arlen                    (axi_arlen_ui_clk_li)
         ,.s_axi_arsize                   (axi_arsize_ui_clk_li)
         ,.s_axi_arburst                  (axi_arburst_ui_clk_li)
         ,.s_axi_arlock                   (axi_arlock_ui_clk_li)
         ,.s_axi_arcache                  (axi_arcache_ui_clk_li)
         ,.s_axi_arprot                   (axi_arprot_ui_clk_li)
         ,.s_axi_arqos                    (4'h0)
         ,.s_axi_arvalid                  (axi_arvalid_ui_clk_li)
         ,.s_axi_arready                  (axi_arready_ui_clk_lo)

         // AXI S Interface Read Data Ports
         ,.s_axi_rid                      (axi_rid_ui_clk_lo)
         ,.s_axi_rdata                    (axi_rdata_ui_clk_lo)
         ,.s_axi_rresp                    (axi_rresp_ui_clk_lo)
         ,.s_axi_rlast                    (axi_rlast_ui_clk_lo)
         ,.s_axi_rvalid                   (axi_rvalid_ui_clk_lo)
         ,.s_axi_rready                   (axi_rready_ui_clk_li)

         // System Clock Ports
         ,.sys_clk_i                      (sys_clk_i)

         // Reference Clock Ports
         ,.clk_ref_i                      (ref_clk_i)

         // Input measured DRAM temperature
         ,.device_temp                    (device_temp_li)

         // Input reset signal
         ,.sys_rst                        (reset_sys_clk_i)
         );

    axi_memory_clock_converter clock_crossing
        // Clocking for the AXI M interface (to DRAM)
        (.m_axi_aclk     (ui_clk_lo)
         ,.m_axi_aresetn (reset_ui_clk_active_low_li)

         // Clocking for the AXI S interface (from core/cache DMA translator)
         ,.s_axi_aclk     (core_clk_i)
         ,.s_axi_aresetn  (reset_core_clk_active_low_li)

         // AXI M bus
         // AXI M Interface Write Address Ports
         ,.m_axi_awid                     (axi_awid_ui_clk_li)
         ,.m_axi_awaddr                   (axi_awaddr_ui_clk_li)
         ,.m_axi_awlen                    (axi_awlen_ui_clk_li)
         ,.m_axi_awsize                   (axi_awsize_ui_clk_li)
         ,.m_axi_awburst                  (axi_awburst_ui_clk_li)
         ,.m_axi_awlock                   (axi_awlock_ui_clk_li)
         ,.m_axi_awcache                  (axi_awcache_ui_clk_li)
         ,.m_axi_awprot                   (axi_awprot_ui_clk_li)
         ,.m_axi_awqos                    (axi_awqos_core_clk_li)
         ,.m_axi_awvalid                  (axi_awvalid_ui_clk_li)
         ,.m_axi_awready                  (axi_awready_ui_clk_lo)
         ,.m_axi_awregion                 (axi_awregion_core_clk_li)

         // AXI M Interface Write Data Ports
         ,.m_axi_wdata                    (axi_wdata_ui_clk_li)
         ,.m_axi_wstrb                    (axi_wstrb_ui_clk_li)
         ,.m_axi_wlast                    (axi_wlast_ui_clk_li)
         ,.m_axi_wvalid                   (axi_wvalid_ui_clk_li)
         ,.m_axi_wready                   (axi_wready_ui_clk_lo)

         // AXI M Interface Write Response Ports
         ,.m_axi_bid                      (axi_bid_ui_clk_lo)
         ,.m_axi_bresp                    (axi_bresp_ui_clk_lo)
         ,.m_axi_bvalid                   (axi_bvalid_ui_clk_lo)
         ,.m_axi_bready                   (axi_bready_ui_clk_li)

         // AXI M Interface Read Address Ports
         ,.m_axi_arid                     (axi_arid_ui_clk_li)
         ,.m_axi_araddr                   (axi_araddr_ui_clk_li)
         ,.m_axi_arlen                    (axi_arlen_ui_clk_li)
         ,.m_axi_arsize                   (axi_arsize_ui_clk_li)
         ,.m_axi_arburst                  (axi_arburst_ui_clk_li)
         ,.m_axi_arlock                   (axi_arlock_ui_clk_li)
         ,.m_axi_arcache                  (axi_arcache_ui_clk_li)
         ,.m_axi_arprot                   (axi_arprot_ui_clk_li)
         ,.m_axi_arqos                    (axi_arqos_core_clk_li)
         ,.m_axi_arvalid                  (axi_arvalid_ui_clk_li)
         ,.m_axi_arready                  (axi_arready_ui_clk_lo)
         ,.m_axi_arregion                 (axi_arregion_core_clk_li)

         // AXI M Interface Read Data Ports
         ,.m_axi_rid                      (axi_rid_ui_clk_lo)
         ,.m_axi_rdata                    (axi_rdata_ui_clk_lo)
         ,.m_axi_rresp                    (axi_rresp_ui_clk_lo)
         ,.m_axi_rlast                    (axi_rlast_ui_clk_lo)
         ,.m_axi_rvalid                   (axi_rvalid_ui_clk_lo)
         ,.m_axi_rready                   (axi_rready_ui_clk_li)

         // AXI S bus
         // AXI S Interface Write Address Ports
         ,.s_axi_awid                     (axi_awid_core_clk_li)
         ,.s_axi_awaddr                   (axi_awaddr_core_clk_li)
         ,.s_axi_awlen                    (axi_awlen_core_clk_li)
         ,.s_axi_awsize                   (axi_awsize_core_clk_li)
         ,.s_axi_awburst                  (axi_awburst_core_clk_li)
         ,.s_axi_awlock                   (axi_awlock_core_clk_li)
         ,.s_axi_awcache                  (axi_awcache_core_clk_li)
         ,.s_axi_awprot                   (axi_awprot_core_clk_li)
         ,.s_axi_awqos                    (4'h0)
         ,.s_axi_awvalid                  (axi_awvalid_core_clk_li)
         ,.s_axi_awready                  (axi_awready_core_clk_lo)
         ,.s_axi_awregion                 (4'h0)

         // AXI S Interface Write Data Ports
         ,.s_axi_wdata                    (axi_wdata_core_clk_li)
         ,.s_axi_wstrb                    (axi_wstrb_core_clk_li)
         ,.s_axi_wlast                    (axi_wlast_core_clk_li)
         ,.s_axi_wvalid                   (axi_wvalid_core_clk_li)
         ,.s_axi_wready                   (axi_wready_core_clk_lo)

         // AXI S Interface Write Response Ports
         ,.s_axi_bid                      (axi_bid_core_clk_lo)
         ,.s_axi_bresp                    (axi_bresp_core_clk_lo)
         ,.s_axi_bvalid                   (axi_bvalid_core_clk_lo)
         ,.s_axi_bready                   (axi_bready_core_clk_li)

         // AXI S Interface Read Address Ports
         ,.s_axi_arid                     (axi_arid_core_clk_li)
         ,.s_axi_araddr                   (axi_araddr_core_clk_li)
         ,.s_axi_arlen                    (axi_arlen_core_clk_li)
         ,.s_axi_arsize                   (axi_arsize_core_clk_li)
         ,.s_axi_arburst                  (axi_arburst_core_clk_li)
         ,.s_axi_arlock                   (axi_arlock_core_clk_li)
         ,.s_axi_arcache                  (axi_arcache_core_clk_li)
         ,.s_axi_arprot                   (axi_arprot_core_clk_li)
         ,.s_axi_arqos                    (4'h0)
         ,.s_axi_arvalid                  (axi_arvalid_core_clk_li)
         ,.s_axi_arready                  (axi_arready_core_clk_lo)
         ,.s_axi_arregion                 (4'h0)

         // AXI S Interface Read Data Ports
         ,.s_axi_rid                      (axi_rid_core_clk_lo)
         ,.s_axi_rdata                    (axi_rdata_core_clk_lo)
         ,.s_axi_rresp                    (axi_rresp_core_clk_lo)
         ,.s_axi_rlast                    (axi_rlast_core_clk_lo)
         ,.s_axi_rvalid                   (axi_rvalid_core_clk_lo)
         ,.s_axi_rready                   (axi_rready_core_clk_li)
        );

    bsg_cache_to_axi
        #(.addr_width_p          (caddr_width_p)
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
        (.clk_i   (core_clk_i)
         ,.reset_i(reset_core_clk_i)

         ,.dma_pkt_i       (dma_pkt_i)
         ,.dma_pkt_v_i     (dma_pkt_v_i)
         ,.dma_pkt_yumi_o  (dma_pkt_yumi_o)

         ,.dma_data_o      (dma_data_o)
         ,.dma_data_v_o    (dma_data_v_o)
         ,.dma_data_ready_i(dma_data_ready_and_i)

         ,.dma_data_i      (dma_data_i)
         ,.dma_data_v_i    (dma_data_v_i)
         ,.dma_data_yumi_o (dma_data_yumi_o)

         ,.axi_awid_o      (axi_awid_core_clk_li)
         ,.axi_awaddr_o    (axi_awaddr_core_clk_li)
         ,.axi_awlen_o     (axi_awlen_core_clk_li)
         ,.axi_awsize_o    (axi_awsize_core_clk_li)
         ,.axi_awburst_o   (axi_awburst_core_clk_li)
         ,.axi_awcache_o   (axi_awcache_core_clk_li)
         ,.axi_awprot_o    (axi_awprot_core_clk_li)
         ,.axi_awlock_o    (axi_awlock_core_clk_li)
         ,.axi_awvalid_o   (axi_awvalid_core_clk_li)
         ,.axi_awready_i   (axi_awready_core_clk_lo)

         ,.axi_wdata_o     (axi_wdata_core_clk_li)
         ,.axi_wstrb_o     (axi_wstrb_core_clk_li)
         ,.axi_wlast_o     (axi_wlast_core_clk_li)
         ,.axi_wvalid_o    (axi_wvalid_core_clk_li)
         ,.axi_wready_i    (axi_wready_core_clk_lo)

         ,.axi_bid_i       (axi_bid_core_clk_lo)
         ,.axi_bresp_i     (axi_bresp_core_clk_lo)
         ,.axi_bvalid_i    (axi_bvalid_core_clk_lo)
         ,.axi_bready_o    (axi_bready_core_clk_li)

         ,.axi_arid_o      (axi_arid_core_clk_li)
         ,.axi_araddr_o    (axi_araddr_core_clk_li)
         ,.axi_arlen_o     (axi_arlen_core_clk_li)
         ,.axi_arsize_o    (axi_arsize_core_clk_li)
         ,.axi_arburst_o   (axi_arburst_core_clk_li)
         ,.axi_arcache_o   (axi_arcache_core_clk_li)
         ,.axi_arprot_o    (axi_arprot_core_clk_li)
         ,.axi_arlock_o    (axi_arlock_core_clk_li)
         ,.axi_arvalid_o   (axi_arvalid_core_clk_li)
         ,.axi_arready_i   (axi_arready_core_clk_lo)

         ,.axi_rid_i       (axi_rid_core_clk_lo)
         ,.axi_rdata_i     (axi_rdata_core_clk_lo)
         ,.axi_rresp_i     (axi_rresp_core_clk_lo)
         ,.axi_rlast_i     (axi_rlast_core_clk_lo)
         ,.axi_rvalid_i    (axi_rvalid_core_clk_lo)
         ,.axi_rready_o    (axi_rready_core_clk_li)
         );

endmodule
