`include "bp_common_defines.svh"
`include "bp_me_defines.svh"
`include "bp_fpga_host_defines.svh"

module arty_parrot
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  import bp_fpga_host_pkg::*;

  #(parameter bp_params_e bp_params_p = e_bp_unicore_l1_tiny_cfg
   `declare_bp_proc_params(bp_params_p)
    , parameter nbf_addr_width_p = paddr_width_p
    , parameter nbf_data_width_p = dword_width_gp
    , localparam nbf_width_lp = `bp_fpga_host_nbf_width(nbf_addr_width_p, nbf_data_width_p)

    , parameter uart_clk_per_bit_p = 10 // 20MHz clock / 2M Baud
    , parameter uart_data_bits_p = 8 // between 5 and 9 bits
    , parameter uart_parity_bit_p = 0 // 0 or 1
    , parameter uart_parity_odd_p = 0 // 0 for even parity, 1 for odd parity
    , parameter uart_stop_bits_p = 1 // 1 or 2

    , parameter io_in_nbf_buffer_els_p = 4
    , parameter io_out_nbf_buffer_els_p = 4

    , localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(daddr_width_p)

    `declare_bp_bedrock_mem_if_widths(paddr_width_p, dword_width_gp, lce_id_width_p, lce_assoc_p, io)
    )
  (input external_clock_i // 100 MHz clock from board
   , input external_reset_n_i // active low reset from red reset button on board

   , output [13:0]ddr3_sdram_addr
   , output [2:0]ddr3_sdram_ba
   , output ddr3_sdram_cas_n
   , output [0:0]ddr3_sdram_ck_n
   , output [0:0]ddr3_sdram_ck_p
   , output [0:0]ddr3_sdram_cke
   , output [0:0]ddr3_sdram_cs_n
   , output [1:0]ddr3_sdram_dm
   , inout [15:0]ddr3_sdram_dq
   , inout [1:0]ddr3_sdram_dqs_n
   , inout [1:0]ddr3_sdram_dqs_p
   , output [0:0]ddr3_sdram_odt
   , output ddr3_sdram_ras_n
   , output ddr3_sdram_reset_n
   , output ddr3_sdram_we_n

   , input logic uart_rx_i
   , output logic uart_tx_o

   //, output logic error_led_o
   , output logic reset_led_o
   , output logic rd_error_led_o
   , output logic wr_error_led_o
   , output logic done_led_o
  );

  // DDR to external
  wire [13:0]ddr3_sdram_addr;
  wire [2:0]ddr3_sdram_ba;
  wire ddr3_sdram_cas_n;
  wire [0:0]ddr3_sdram_ck_n;
  wire [0:0]ddr3_sdram_ck_p;
  wire [0:0]ddr3_sdram_cke;
  wire [0:0]ddr3_sdram_cs_n;
  wire [1:0]ddr3_sdram_dm;
  wire [15:0]ddr3_sdram_dq;
  wire [1:0]ddr3_sdram_dqs_n;
  wire [1:0]ddr3_sdram_dqs_p;
  wire [0:0]ddr3_sdram_odt;
  wire ddr3_sdram_ras_n;
  wire ddr3_sdram_reset_n;
  wire ddr3_sdram_we_n;

  `declare_bp_bedrock_mem_if(paddr_width_p, dword_width_gp, lce_id_width_p, lce_assoc_p, io)

  logic fpga_host_error_lo;
  assign reset_led_o = external_reset_n_i ? 1'b0 : 1'b1;
  logic error_led_o;
  assign error_led_o = fpga_host_error_lo;

  // I/O command buses
  // to FPGA Host
  bp_bedrock_io_mem_msg_header_s fpga_host_io_cmd_li, fpga_host_io_resp_lo;
  logic [dword_width_gp-1:0] fpga_host_io_cmd_data_li, fpga_host_io_resp_data_lo;
  logic fpga_host_io_cmd_v_li, fpga_host_io_cmd_ready_and_lo;
  logic fpga_host_io_resp_v_lo, fpga_host_io_resp_yumi_li;
  logic fpga_host_io_cmd_last_li, fpga_host_io_resp_last_lo;

  // from FPGA Host
  bp_bedrock_io_mem_msg_header_s fpga_host_io_cmd_lo, fpga_host_io_resp_li;
  logic [dword_width_gp-1:0] fpga_host_io_cmd_data_lo, fpga_host_io_resp_data_li;
  logic fpga_host_io_cmd_v_lo, fpga_host_io_cmd_yumi_li;
  logic fpga_host_io_resp_v_li, fpga_host_io_resp_ready_and_lo;
  logic fpga_host_io_cmd_last_lo, fpga_host_io_resp_last_li;

  // bsg cache DRAM buses
  // TODO: assertion to confirm l2_fill_width is 64-bits (with tiny_l1 config,
  // it is)
  logic [dma_pkt_width_lp-1:0] dma_pkt_li;
  logic                        dma_pkt_v_li;
  logic                        dma_pkt_yumi_lo;

  logic[l2_fill_width_p-1:0]   dma_data_lo;
  logic                        dma_data_v_lo;
  logic                        dma_data_ready_and_li;

  logic [l2_fill_width_p-1:0]  dma_data_li;
  logic                        dma_data_v_li;
  logic                        dma_data_yumi_lo;

  logic proc_reset_o;
  logic mig_ddr_init_calib_complete_o;

  // AXI 4 Lite signals
  // All core logic runs on the axi_clk at ~20 MHz
  logic axi_clk, axi_rst_n;
  wire axi_rst = ~axi_rst_n;

  // AXI bus from cache DMA translator to clock domain crossing
  logic [27:0] s_axi_araddr;
  logic [1:0]  s_axi_arburst;
  logic [3:0]  s_axi_arcache;
  logic [3:0]  s_axi_arid;
  logic [7:0]  s_axi_arlen;
  logic [0:0]  s_axi_arlock;
  logic [2:0]  s_axi_arprot;
  logic [3:0]  s_axi_arqos;
  logic        s_axi_arready;
  logic [3:0]  s_axi_arregion;
  logic [2:0]  s_axi_arsize;
  logic        s_axi_arvalid;

  logic [27:0] s_axi_awaddr;
  logic [1:0]  s_axi_awburst;
  logic [3:0]  s_axi_awcache;
  logic [3:0]  s_axi_awid;
  logic [7:0]  s_axi_awlen;
  logic [0:0]  s_axi_awlock;
  logic [2:0]  s_axi_awprot;
  logic [3:0]  s_axi_awqos;
  logic        s_axi_awready;
  logic [3:0]  s_axi_awregion;
  logic [2:0]  s_axi_awsize;
  logic        s_axi_awvalid;

  logic [3:0]  s_axi_bid;
  logic        s_axi_bready;
  logic [1:0]  s_axi_bresp;
  logic        s_axi_bvalid;

  logic [63:0] s_axi_rdata;
  logic [3:0]  s_axi_rid;
  logic        s_axi_rlast;
  logic        s_axi_rready;
  logic [1:0]  s_axi_rresp;
  logic        s_axi_rvalid;

  logic [63:0] s_axi_wdata;
  logic        s_axi_wlast;
  logic        s_axi_wready;
  logic [7:0]  s_axi_wstrb;
  logic        s_axi_wvalid;

  memory_design_wrapper memory_ip_subsystem
   (.ddr3_sdram_addr(ddr3_sdram_addr),
    .ddr3_sdram_ba(ddr3_sdram_ba),
    .ddr3_sdram_cas_n(ddr3_sdram_cas_n),
    .ddr3_sdram_ck_n(ddr3_sdram_ck_n),
    .ddr3_sdram_ck_p(ddr3_sdram_ck_p),
    .ddr3_sdram_cke(ddr3_sdram_cke),
    .ddr3_sdram_cs_n(ddr3_sdram_cs_n),
    .ddr3_sdram_dm(ddr3_sdram_dm),
    .ddr3_sdram_dq(ddr3_sdram_dq),
    .ddr3_sdram_dqs_n(ddr3_sdram_dqs_n),
    .ddr3_sdram_dqs_p(ddr3_sdram_dqs_p),
    .ddr3_sdram_odt(ddr3_sdram_odt),
    .ddr3_sdram_ras_n(ddr3_sdram_ras_n),
    .ddr3_sdram_reset_n(ddr3_sdram_reset_n),
    .ddr3_sdram_we_n(ddr3_sdram_we_n),
    .external_clock_i(external_clock_i),
    .external_reset_n_i(external_reset_n_i),
    .mig_ddr_init_calib_complete_o(mig_ddr_init_calib_complete_o),
    .proc_reset_o(proc_reset_o),
    .s_axi_clk_20M_o(axi_clk),
    .s_axi_reset_n_o(axi_rst_n)

    // AXI S Interface Write Address Ports
    ,.s_axi_awid                     (s_axi_awid)
    ,.s_axi_awaddr                   (s_axi_awaddr)
    ,.s_axi_awlen                    (s_axi_awlen)
    ,.s_axi_awsize                   (s_axi_awsize)
    ,.s_axi_awburst                  (s_axi_awburst)
    ,.s_axi_awlock                   (s_axi_awlock)
    ,.s_axi_awcache                  (s_axi_awcache)
    ,.s_axi_awprot                   (s_axi_awprot)
    ,.s_axi_awqos                    (4'h0)
    ,.s_axi_awvalid                  (s_axi_awvalid)
    ,.s_axi_awready                  (s_axi_awready)

    // AXI S Interface Write Data Ports
    ,.s_axi_wdata                    (s_axi_wdata)
    ,.s_axi_wstrb                    (s_axi_wstrb)
    ,.s_axi_wlast                    (s_axi_wlast)
    ,.s_axi_wvalid                   (s_axi_wvalid)
    ,.s_axi_wready                   (s_axi_wready)

    // AXI S Interface Write Response Ports
    ,.s_axi_bid                      (s_axi_bid)
    ,.s_axi_bresp                    (s_axi_bresp)
    ,.s_axi_bvalid                   (s_axi_bvalid)
    ,.s_axi_bready                   (s_axi_bready)

    // AXI S Interface Read Address Ports
    ,.s_axi_arid                     (s_axi_arid)
    ,.s_axi_araddr                   (s_axi_araddr)
    ,.s_axi_arlen                    (s_axi_arlen)
    ,.s_axi_arsize                   (s_axi_arsize)
    ,.s_axi_arburst                  (s_axi_arburst)
    ,.s_axi_arlock                   (s_axi_arlock)
    ,.s_axi_arcache                  (s_axi_arcache)
    ,.s_axi_arprot                   (s_axi_arprot)
    ,.s_axi_arqos                    (4'h0)
    ,.s_axi_arvalid                  (s_axi_arvalid)
    ,.s_axi_arready                  (s_axi_arready)

    // AXI S Interface Read Data Ports
    ,.s_axi_rid                      (s_axi_rid)
    ,.s_axi_rdata                    (s_axi_rdata)
    ,.s_axi_rresp                    (s_axi_rresp)
    ,.s_axi_rlast                    (s_axi_rlast)
    ,.s_axi_rvalid                   (s_axi_rvalid)
    ,.s_axi_rready                   (s_axi_rready)
    );

    bsg_cache_to_axi
      #(.addr_width_p          (daddr_width_p)
        ,.block_size_in_words_p(cce_block_width_p/dword_width_gp)
        ,.data_width_p         (dword_width_gp)
        ,.num_cache_p          (num_cce_p) // 1 - multicore not yet supported
        ,.axi_id_width_p       (4)
        ,.axi_data_width_p     (64)
        ,.axi_burst_len_p      (4)
        )
      cache_to_axi
      (.clk_i                  (axi_clk)
       ,.reset_i               (axi_rst)

       ,.dma_pkt_i             (dma_pkt_li)
       ,.dma_pkt_v_i           (dma_pkt_v_li)
       ,.dma_pkt_yumi_o        (dma_pkt_yumi_lo)

       ,.dma_data_o            (dma_data_lo)
       ,.dma_data_v_o          (dma_data_v_lo)
       ,.dma_data_ready_i      (dma_data_ready_and_li)

       ,.dma_data_i            (dma_data_li)
       ,.dma_data_v_i          (dma_data_v_li)
       ,.dma_data_yumi_o       (dma_data_yumi_lo)

       ,.axi_awid_o            (s_axi_awid)
       ,.axi_awaddr_addr_o     (s_axi_awaddr)
       ,.axi_awaddr_cache_id_o (/*unused*/)
       ,.axi_awlen_o           (s_axi_awlen)
       ,.axi_awsize_o          (s_axi_awsize)
       ,.axi_awburst_o         (s_axi_awburst)
       ,.axi_awcache_o         (s_axi_awcache)
       ,.axi_awprot_o          (s_axi_awprot)
       ,.axi_awlock_o          (s_axi_awlock)
       ,.axi_awvalid_o         (s_axi_awvalid)
       ,.axi_awready_i         (s_axi_awready)

       ,.axi_wdata_o           (s_axi_wdata)
       ,.axi_wstrb_o           (s_axi_wstrb)
       ,.axi_wlast_o           (s_axi_wlast)
       ,.axi_wvalid_o          (s_axi_wvalid)
       ,.axi_wready_i          (s_axi_wready)

       ,.axi_bid_i             (s_axi_bid)
       ,.axi_bresp_i           (s_axi_bresp)
       ,.axi_bvalid_i          (s_axi_bvalid)
       ,.axi_bready_o          (s_axi_bready)

       ,.axi_arid_o            (s_axi_arid)
       ,.axi_araddr_addr_o     (s_axi_araddr)
       ,.axi_araddr_cache_id_o (/*unused*/)
       ,.axi_arlen_o           (s_axi_arlen)
       ,.axi_arsize_o          (s_axi_arsize)
       ,.axi_arburst_o         (s_axi_arburst)
       ,.axi_arcache_o         (s_axi_arcache)
       ,.axi_arprot_o          (s_axi_arprot)
       ,.axi_arlock_o          (s_axi_arlock)
       ,.axi_arvalid_o         (s_axi_arvalid)
       ,.axi_arready_i         (s_axi_arready)

       ,.axi_rid_i             (s_axi_rid)
       ,.axi_rdata_i           (s_axi_rdata)
       ,.axi_rresp_i           (s_axi_rresp)
       ,.axi_rlast_i           (s_axi_rlast)
       ,.axi_rvalid_i          (s_axi_rvalid)
       ,.axi_rready_o          (s_axi_rready)
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
      (.clk_i(axi_clk)
       ,.reset_i(axi_rst)

       // to FPGA Host
       ,.io_cmd_header_i     (fpga_host_io_cmd_li)
       ,.io_cmd_data_i       (fpga_host_io_cmd_data_li)
       ,.io_cmd_v_i          (fpga_host_io_cmd_v_li)
       ,.io_cmd_ready_and_o  (fpga_host_io_cmd_ready_and_lo)
       ,.io_cmd_last_i       (fpga_host_io_cmd_last_li)

       ,.io_resp_header_o    (fpga_host_io_resp_lo)
       ,.io_resp_data_o      (fpga_host_io_resp_data_lo)
       ,.io_resp_v_o         (fpga_host_io_resp_v_lo)
       ,.io_resp_yumi_i      (fpga_host_io_resp_yumi_li)
       ,.io_resp_last_o      (fpga_host_io_resp_last_lo)

       // from FPGA Host
       ,.io_cmd_header_o     (fpga_host_io_cmd_lo)
       ,.io_cmd_data_o       (fpga_host_io_cmd_data_lo)
       ,.io_cmd_v_o          (fpga_host_io_cmd_v_lo)
       ,.io_cmd_yumi_i       (fpga_host_io_cmd_yumi_li)
       ,.io_cmd_last_o       (fpga_host_io_cmd_last_lo)

       ,.io_resp_header_i    (fpga_host_io_resp_li)
       ,.io_resp_data_i      (fpga_host_io_resp_data_li)
       ,.io_resp_v_i         (fpga_host_io_resp_v_li)
       ,.io_resp_ready_and_o (fpga_host_io_resp_ready_and_lo)
       ,.io_resp_last_i      (fpga_host_io_resp_last_li)

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
    (.clk_i(axi_clk)
     ,.reset_i(axi_rst)

     // I/O to FPGA Host
     ,.io_cmd_header_o      (fpga_host_io_cmd_li)
     ,.io_cmd_data_o        (fpga_host_io_cmd_data_li)
     ,.io_cmd_v_o           (fpga_host_io_cmd_v_li)
     ,.io_cmd_ready_and_i   (fpga_host_io_cmd_ready_and_lo)
     ,.io_cmd_last_o        (fpga_host_io_cmd_last_li)

     ,.io_resp_header_i     (fpga_host_io_resp_lo)
     ,.io_resp_data_i       (fpga_host_io_resp_data_lo)
     ,.io_resp_v_i          (fpga_host_io_resp_v_lo)
     ,.io_resp_yumi_o       (fpga_host_io_resp_yumi_li)
     ,.io_resp_last_i       (fpga_host_io_resp_last_lo)

     // I/O from FPGA host
     ,.io_cmd_header_i      (fpga_host_io_cmd_lo)
     ,.io_cmd_data_i        (fpga_host_io_cmd_data_lo)
     ,.io_cmd_v_i           (fpga_host_io_cmd_v_lo)
     ,.io_cmd_yumi_o        (fpga_host_io_cmd_yumi_li)
     ,.io_cmd_last_i        (fpga_host_io_cmd_last_lo)

     ,.io_resp_header_o     (fpga_host_io_resp_li)
     ,.io_resp_data_o       (fpga_host_io_resp_data_li)
     ,.io_resp_v_o          (fpga_host_io_resp_v_li)
     ,.io_resp_ready_and_i  (fpga_host_io_resp_ready_and_lo)
     ,.io_resp_last_o       (fpga_host_io_resp_last_li)

     // DRAM interface
     ,.dma_pkt_o            (dma_pkt_li)
     ,.dma_pkt_v_o          (dma_pkt_v_li)
     ,.dma_pkt_yumi_i       (dma_pkt_yumi_lo)

     ,.dma_data_i           (dma_data_lo)
     ,.dma_data_v_i         (dma_data_v_lo)
     ,.dma_data_ready_and_o (dma_data_ready_and_li)

     ,.dma_data_o           (dma_data_li)
     ,.dma_data_v_o         (dma_data_v_li)
     ,.dma_data_yumi_i      (dma_data_yumi_lo)
    );

  // TODO: bsg cache dma to AXI 4 Lite converter
  /*
  axi4_lite_traffic_gen mem_traffic_gen
    (.clk_i(axi_clk),
     .reset_n_i(axi_rst_n),
     // read address
     .araddr_o(s_axi_lite_i_araddr),
     .arprot_o(s_axi_lite_i_arprot),
     .arready_i(s_axi_lite_i_arready),
     .arvalid_o(s_axi_lite_i_arvalid),
     // write address
     .awaddr_o(s_axi_lite_i_awaddr),
     .awprot_o(s_axi_lite_i_awprot),
     .awready_i(s_axi_lite_i_awready),
     .awvalid_o(s_axi_lite_i_awvalid),
     // write response
     .bready_o(s_axi_lite_i_bready),
     .bresp_i(s_axi_lite_i_bresp),
     .bvalid_i(s_axi_lite_i_bvalid),
     // read data
     .rdata_i(s_axi_lite_i_rdata),
     .rready_o(s_axi_lite_i_rready),
     .rresp_o(s_axi_lite_i_rresp),
     .rvalid_i(s_axi_lite_i_rvalid),
     // write data
     .wdata_o(s_axi_lite_i_wdata),
     .wready_i(s_axi_lite_i_wready),
     .wstrb_o(s_axi_lite_i_wstrb),
     .wvalid_o(s_axi_lite_i_wvalid)
     ,.rd_error_o(rd_error_led_o)
     ,.wr_error_o(wr_error_led_o)
     ,.done_o(done_led_o)
     );
  */

endmodule
