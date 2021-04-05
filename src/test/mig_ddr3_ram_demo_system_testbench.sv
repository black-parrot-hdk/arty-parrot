`timescale 1ns / 1ps

`include "bp_common_defines.svh"
`include "bp_common_aviary_defines.svh"

// Below macros copied from external/basejump_stl/bsg_cache/bsg_cache_pkg.v
// TODO: fix
// `define declare_bsg_cache_dma_pkt_s(addr_width_mp) \
//   typedef struct packed {               \
//     logic write_not_read;               \
//     logic [addr_width_mp-1:0] addr;     \
//   } bsg_cache_dma_pkt_s

// `define bsg_cache_dma_pkt_width(addr_width_mp)    \
//   (1+addr_width_mp)

module mig_ddr3_ram_demo_system_testbench
    import bp_common_pkg::*;
    import bsg_cache_pkg::*;

    #(parameter bp_params_e bp_params_p = e_bp_unicore_l1_tiny_cfg
      `declare_bp_proc_params(bp_params_p)
      `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)
      ,localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(caddr_width_p)
      )
    ();

    parameter MASTER_CLOCK_PERIOD_NS = 10;
    parameter reset_clks_p = 64;

    // DRAM control lines and other controller-specific I/O ports
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

    wire input_select_switch_li = 1'b1;

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
    bit master_reset_active_low_i = !master_reset_i;

    mig_ddr3_ram_demo_system
        #(.bp_params_p(bp_params_p))
        dut
        (.master_clk_100mhz_i(master_clk_100mhz_i)
         ,.master_reset_active_low_i(master_reset_active_low_i)

         ,.reset_led_o(reset_led_lo)
         ,.input_select_switch_i(input_select_switch_li)

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
endmodule