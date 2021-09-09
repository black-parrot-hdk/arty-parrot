`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 09/08/2021 03:16:28 PM
// Design Name:
// Module Name: arty
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


module arty
  (ddr3_sdram_addr,
  ddr3_sdram_ba,
  ddr3_sdram_cas_n,
  ddr3_sdram_ck_n,
  ddr3_sdram_ck_p,
  ddr3_sdram_cke,
  ddr3_sdram_cs_n,
  ddr3_sdram_dm,
  ddr3_sdram_dq,
  ddr3_sdram_dqs_n,
  ddr3_sdram_dqs_p,
  ddr3_sdram_odt,
  ddr3_sdram_ras_n,
  ddr3_sdram_reset_n,
  ddr3_sdram_we_n,
  rd_error_led_o,
  wr_error_led_o,
  done_led_o,
  reset_led_o,
  external_clock_i,
  external_reset_n_i);

  output [13:0]ddr3_sdram_addr;
  output [2:0]ddr3_sdram_ba;
  output ddr3_sdram_cas_n;
  output [0:0]ddr3_sdram_ck_n;
  output [0:0]ddr3_sdram_ck_p;
  output [0:0]ddr3_sdram_cke;
  output [0:0]ddr3_sdram_cs_n;
  output [1:0]ddr3_sdram_dm;
  inout [15:0]ddr3_sdram_dq;
  inout [1:0]ddr3_sdram_dqs_n;
  inout [1:0]ddr3_sdram_dqs_p;
  output [0:0]ddr3_sdram_odt;
  output ddr3_sdram_ras_n;
  output ddr3_sdram_reset_n;
  output ddr3_sdram_we_n;
  output logic rd_error_led_o;
  output logic wr_error_led_o;
  output logic done_led_o;
  output logic reset_led_o;
  input external_clock_i;
  input external_reset_n_i;

  assign reset_led_o = external_reset_n_i ? 1'b0 : 1'b1;

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
  wire mig_ddr_init_calib_complete_o;

  wire proc_reset_o;

  // AXI
  wire s_axi_clk_20M_o; // connects to traffic gen as clock
  wire [27:0]s_axi_lite_i_araddr;
  wire [2:0]s_axi_lite_i_arprot;
  wire s_axi_lite_i_arready;
  wire s_axi_lite_i_arvalid;
  wire [27:0]s_axi_lite_i_awaddr;
  wire [2:0]s_axi_lite_i_awprot;
  wire s_axi_lite_i_awready;
  wire s_axi_lite_i_awvalid;
  wire s_axi_lite_i_bready;
  wire [1:0]s_axi_lite_i_bresp;
  wire s_axi_lite_i_bvalid;
  wire [63:0]s_axi_lite_i_rdata;
  wire s_axi_lite_i_rready;
  wire [1:0]s_axi_lite_i_rresp;
  wire s_axi_lite_i_rvalid;
  wire [63:0]s_axi_lite_i_wdata;
  wire s_axi_lite_i_wready;
  wire [7:0]s_axi_lite_i_wstrb;
  wire s_axi_lite_i_wvalid;
  wire [0:0]s_axi_reset_n_o; // connects to traffic gen as reset_n_i

  // external
  wire external_clock_i;
  wire external_reset_n_i;

  axi4_lite_traffic_gen mem_traffic_gen
    (.clk_i(s_axi_clk_20M_o),
    .reset_n_i(s_axi_reset_n_o),
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

  design_1_wrapper design_ip
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
    .mig_ddr_init_calib_complete_o(mig_ddr_init_calib_complete_o),
    .proc_reset_o(proc_reset_o),
    .s_axi_clk_20M_o(s_axi_clk_20M_o),
    .s_axi_lite_i_araddr(s_axi_lite_i_araddr),
    .s_axi_lite_i_arprot(s_axi_lite_i_arprot),
    .s_axi_lite_i_arready(s_axi_lite_i_arready),
    .s_axi_lite_i_arvalid(s_axi_lite_i_arvalid),
    .s_axi_lite_i_awaddr(s_axi_lite_i_awaddr),
    .s_axi_lite_i_awprot(s_axi_lite_i_awprot),
    .s_axi_lite_i_awready(s_axi_lite_i_awready),
    .s_axi_lite_i_awvalid(s_axi_lite_i_awvalid),
    .s_axi_lite_i_bready(s_axi_lite_i_bready),
    .s_axi_lite_i_bresp(s_axi_lite_i_bresp),
    .s_axi_lite_i_bvalid(s_axi_lite_i_bvalid),
    .s_axi_lite_i_rdata(s_axi_lite_i_rdata),
    .s_axi_lite_i_rready(s_axi_lite_i_rready),
    .s_axi_lite_i_rresp(s_axi_lite_i_rresp),
    .s_axi_lite_i_rvalid(s_axi_lite_i_rvalid),
    .s_axi_lite_i_wdata(s_axi_lite_i_wdata),
    .s_axi_lite_i_wready(s_axi_lite_i_wready),
    .s_axi_lite_i_wstrb(s_axi_lite_i_wstrb),
    .s_axi_lite_i_wvalid(s_axi_lite_i_wvalid),
    .s_axi_reset_n_o(s_axi_reset_n_o),
    .external_clock_i(external_clock_i),
    .external_reset_n_i(external_reset_n_i));
endmodule
