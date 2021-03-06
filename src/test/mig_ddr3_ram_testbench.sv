`timescale 1ns / 1ps

`include "bp_common_defines.svh"
`include "bp_common_aviary_defines.svh"

module mig_ddr3_ram_testbench
    import bp_common_pkg::*;
    import bsg_cache_pkg::*;

    #(parameter bp_params_e bp_params_p = e_bp_unicore_l1_tiny_cfg
      `declare_bp_proc_params(bp_params_p)
      `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)
      ,localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(caddr_width_p)
      )
    ();

    parameter SYS_CLOCK_PERIOD_NS = 10;
    parameter REF_CLOCK_PERIOD_NS = 5;
    parameter CORE_CLOCK_PERIOD_NS = 20;
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

    logic        init_calib_complete_lo;


    // Clock and reset which drive the memory controller
    bit sys_clk_li, ref_clk_li, core_clk_li;
    bsg_nonsynth_clock_gen
        #(.cycle_time_p(SYS_CLOCK_PERIOD_NS*1000 /* picoseconds */))
        clock_gen_sys_clk
        (.o(sys_clk_li));
    bsg_nonsynth_clock_gen
        #(.cycle_time_p(REF_CLOCK_PERIOD_NS*1000 /* picoseconds */))
        clock_gen_ref_clk
        (.o(ref_clk_li));
    bsg_nonsynth_clock_gen
        #(.cycle_time_p(CORE_CLOCK_PERIOD_NS*1000 /* picoseconds */))
        clock_gen_core_clk
        (.o(core_clk_li));

    bit master_reset_li;
    bsg_nonsynth_reset_gen
        #(.num_clocks_p(1)
          ,.reset_cycles_lo_p(0)
          ,.reset_cycles_hi_p(reset_clks_p)
        )
        reset_gen
        (.clk_i(sys_clk_li)
         ,.async_reset_o(master_reset_li)
        );

    // in simulation, fake the synchronized clocks
    wire reset_sys_clk_li = master_reset_li;
    wire reset_core_clk_li = master_reset_li;

    logic [dma_pkt_width_lp-1:0] dram_dma_pkt_li;
    logic                        dram_dma_pkt_v_li;
    logic                        dram_dma_pkt_yumi_lo;

    logic [l2_fill_width_p-1:0]  dram_dma_data_lo;
    logic                        dram_dma_data_v_lo;
    logic                        dram_dma_data_ready_and_li;

    logic [l2_fill_width_p-1:0]  dram_dma_data_li;
    logic                        dram_dma_data_v_li;
    logic                        dram_dma_data_yumi_lo;

    `declare_bsg_cache_dma_pkt_s(caddr_width_p);
    bsg_cache_dma_pkt_s dram_dma_pkt;
    assign dram_dma_pkt_li = dram_dma_pkt;

    mig_ddr3_ram
        #(.bp_params_p(bp_params_p))
        ram
        (.sys_clk_i(sys_clk_li)
         ,.reset_sys_clk_i(reset_sys_clk_li)
         ,.ref_clk_i(ref_clk_li)
         ,.core_clk_i(core_clk_li)
         ,.reset_core_clk_i(reset_core_clk_li)

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

         ,.init_calib_complete_o(init_calib_complete_lo)

         // BP core memory interface
         ,.dma_pkt_i            (dram_dma_pkt_li)
         ,.dma_pkt_v_i          (dram_dma_pkt_v_li)
         ,.dma_pkt_yumi_o       (dram_dma_pkt_yumi_lo)

         ,.dma_data_o           (dram_dma_data_lo)
         ,.dma_data_v_o         (dram_dma_data_v_lo)
         ,.dma_data_ready_and_i (dram_dma_data_ready_and_li)

         ,.dma_data_i           (dram_dma_data_li)
         ,.dma_data_v_i         (dram_dma_data_v_li)
         ,.dma_data_yumi_o      (dram_dma_data_yumi_lo)
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

    task write_data_chunk(input logic [63:0] data);
      dram_dma_data_li = data;
      do @(posedge core_clk_li); while (!dram_dma_data_yumi_lo);
    endtask

    task read_data_chunk_into(output logic [63:0] data);
      do @(posedge core_clk_li); while (!dram_dma_data_v_lo);
      data = dram_dma_data_lo;
    endtask

    integer i;
    logic [0:7][63:0] read_data;
    initial begin
        dram_dma_pkt_v_li = 1'b0;
        dram_dma_data_v_li = 1'b0;
        dram_dma_data_ready_and_li  = 1'b0;

        // wait until memory is ready
        wait(init_calib_complete_lo == 1'b1);
        #(5*1000 /* 5 microseconds */)
        @(posedge core_clk_li);

        // Signal a write starting at 0x100
        dram_dma_pkt.write_not_read = 1'b1;
        dram_dma_pkt.addr           = 'h100;
        dram_dma_pkt_v_li           = 1'b1;

        // wait for metadata packet handshake
        wait(dram_dma_pkt_yumi_lo == 1'b1);
        @(posedge core_clk_li);
        dram_dma_pkt_v_li  = 1'b0;

        // Send 512 bits of data (64 bytes), in 64-bit chunks
        // Chunks are each 0xDEADBEEF, prefixed with a 32-bit counter from 0 through 7
        dram_dma_data_v_li = 1'b1;
        for (i = 0; i < 8; i ++) begin
          write_data_chunk({ i, 32'hDEADBEEF });
        end
        dram_dma_data_v_li = 1'b0;

        // Pause for a while
        #(5*1000 /* 5 microseconds */)
        @(posedge core_clk_li);

        // Request a read from 0x100
        dram_dma_pkt.write_not_read = 1'b0;
        dram_dma_pkt.addr           = 'h100;
        dram_dma_pkt_v_li           = 1'b1;

        wait(dram_dma_pkt_yumi_lo == 1'b1);
        @(posedge core_clk_li);
        dram_dma_pkt_v_li  = 1'b0;


        // Read and handshake eight data packets
        dram_dma_data_ready_and_li  = 1'b1;
        for (i = 0; i < 8; i ++) begin
          read_data_chunk_into(read_data[i]);
        end
        dram_dma_data_ready_and_li  = 1'b0;
    end

endmodule