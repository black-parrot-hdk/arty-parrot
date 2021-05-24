`include "bp_mig_ddr3_ram_interface.svh"

module mig_ddr3_ram_demo_system
  import bp_common_pkg::*;

    #(parameter bp_params_e bp_params_p = e_bp_unicore_l1_tiny_cfg
     `declare_bp_proc_params(bp_params_p)
     `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)
      )
    (input master_clk_100mhz_i
     ,input master_reset_active_low_i
     ,`declare_mig_ddr3_native_control_ports
     ,input logic input_select_switch_i
     ,output logic pass_led_o
     ,output logic reset_led_o
    );

    localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(caddr_width_p);

    wire master_reset_i = !master_reset_active_low_i;

    // Top-level clock, generated by the RAM controller (to avoid multiple clocks)
    logic clock_lo;
    logic reset_lo;

    logic init_calib_complete_lo;

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

    mig_ddr3_ram
        #(.bp_params_p(bp_params_p))
        dram
        (.master_clk_100mhz_i(master_clk_100mhz_i)
         ,.master_reset_i(master_reset_i)

         ,.clk_o(clock_lo)
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

    logic [3:0] write_blocks_remaining_r, write_blocks_remaining_n;
    logic write_pkt_complete_r, write_pkt_complete_n;
    logic read_pkt_complete_r, read_pkt_complete_n;
    logic all_data_valid_r, all_data_valid_n;

    `declare_bsg_cache_dma_pkt_s(caddr_width_p);
    bsg_cache_dma_pkt_s dram_dma_pkt;
    assign dram_dma_pkt_li = dram_dma_pkt;

    assign dram_dma_pkt.write_not_read = write_blocks_remaining_r > 0;
    assign dram_dma_pkt.addr = 'h100;
    assign dram_dma_pkt_v_li = (write_blocks_remaining_r == 8 && !write_pkt_complete_r) || (write_blocks_remaining_r == 0 && !read_pkt_complete_r);

    assign dram_dma_data_ready_and_li = write_blocks_remaining_r == 0;

    // If switch is low, "incorrect" data will be written to RAM, which should make the test fail.
    assign dram_dma_data_li = input_select_switch_i ? 'hDEADBEEFDEADBEEF : 'h0;
    assign dram_dma_data_v_li = write_blocks_remaining_r > 0;

    always_comb begin
      if (dram_dma_data_v_li && dram_dma_data_yumi_lo)
        write_blocks_remaining_n = write_blocks_remaining_r - 1;
      else
        write_blocks_remaining_n = write_blocks_remaining_r;

      if (!dram_dma_pkt.write_not_read && dram_dma_pkt_v_li && dram_dma_pkt_yumi_lo)
        read_pkt_complete_n = 1'b1;
      else
        read_pkt_complete_n = read_pkt_complete_r;

      if (dram_dma_pkt.write_not_read && dram_dma_pkt_v_li && dram_dma_pkt_yumi_lo)
        write_pkt_complete_n = 1'b1;
      else
        write_pkt_complete_n = write_pkt_complete_r;

      if (dram_dma_data_ready_and_li && dram_dma_data_v_lo)
        all_data_valid_n = all_data_valid_r && dram_dma_data_lo == 'hDEADBEEFDEADBEEF;
      else
        all_data_valid_n = all_data_valid_r;
    end

    always_ff @(posedge clock_lo) begin
      if (reset_lo) begin
        write_blocks_remaining_r <= 8;
        read_pkt_complete_r      <= 1'b0;
        write_pkt_complete_r     <= 1'b0;

        all_data_valid_r         <= 1'b1;
      end else begin
        write_blocks_remaining_r <= write_blocks_remaining_n;
        read_pkt_complete_r      <= read_pkt_complete_n;
        write_pkt_complete_r     <= write_pkt_complete_n;

        all_data_valid_r         <= all_data_valid_n;
      end
    end

    assign reset_led_o = reset_lo;
    assign pass_led_o = all_data_valid_r;

endmodule