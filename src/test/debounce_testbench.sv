`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/14/2021 07:37:41 PM
// Design Name: 
// Module Name: testbench
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


module testbench(
  );
  parameter CLOCK_PERIOD_NS = 10;
  parameter N = 11;
  
  logic clk, reset, btn_li, db_lo;
  
  debounce
   #(.width_p(N))
    DUT
     (.clk_i(clk)
      ,.reset_i(reset)
      ,.button_i(btn_li)
      ,.debounce_o(db_lo)
      );
      
  initial begin
     clk = 1'b0;
     btn_li = 1'b0;
     reset = 1'b1;
     #(CLOCK_PERIOD_NS*200);
     reset = 1'b0;
  end
  
  always begin
    #(CLOCK_PERIOD_NS/2) clk = ~clk;
  end
  
  always begin
    #40000 btn_li = 1'b1;
    
    #400 btn_li = 1'b0;		
    
    #800 btn_li = 1'b1;	
    
    #800 btn_li = 1'b0;				
    
    #800 btn_li = 1'b1;
    
    #40000 btn_li = 1'b0;
    
    #4000 btn_li = 1'b1;		
    
    #40000 btn_li = 1'b0;
    
    #400 btn_li = 1'b1;
    
    #800 btn_li = 1'b0;		
    
    #800 btn_li = 1'b1;
    
    #800 btn_li = 1'b0;
    
    #40000 btn_li = 1'b1;		
    
    #4000 btn_li = 1'b0;
  end
  
endmodule
