`include "bsg_defines.v"

// implemented from diagram at: https://www.digikey.com/eewiki/pages/viewpage.action?pageId=13599139

module debounce
  #(parameter width_p = 11
    , localparam max_cnt_lp = (1 << width_p)
    , localparam ptr_width_lp = `BSG_SAFE_CLOG2(max_cnt_lp+1)
    )
  (input   clk_i
   , input reset_i
   , input button_i
   , output logic debounce_o
   );

  logic dff1_lo, dff2_lo;
  logic cnt_clear, cnt_up;
  logic [ptr_width_lp-1:0] cnt_lo;
  logic db_li;
  assign cnt_clear = dff1_lo ^ dff2_lo;
  assign cnt_up = ~(cnt_lo[width_p-1]) & ~cnt_clear;
  assign db_li = (cnt_lo[width_p-1] == 1'b1) ? dff2_lo : debounce_o;

  bsg_dff_reset
   #(.width_p(1)
     ,.reset_val_p(0)
     )
   dff1
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.data_i(button_i)
     ,.data_o(dff1_lo)
     );

  bsg_dff_reset
   #(.width_p(1)
     ,.reset_val_p(0)
     )
   dff2
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.data_i(dff1_lo)
     ,.data_o(dff2_lo)
     );

  bsg_dff_reset
   #(.width_p(1)
     ,.reset_val_p(0)
     )
   debounce_out
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.data_i(db_li)
     ,.data_o(debounce_o)
     );

  bsg_counter_clear_up
   #(.max_val_p(max_cnt_lp)
     ,.init_val_p(0)
     )
   debounce_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.clear_i(cnt_clear)
     ,.up_i(cnt_up)
     ,.count_o(cnt_lo)
     );

endmodule
