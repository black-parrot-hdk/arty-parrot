`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/01/2021 06:31:55 PM
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


module testbench();

    parameter CLOCK_PERIOD_NS = 10; // 100 MHz
    localparam clk_per_bit_p = 10416;
    localparam ns_per_bit_p = (clk_per_bit_p * CLOCK_PERIOD_NS);

    bit clk = 1'b0;
    bit reset = 1'b1;
    always #(CLOCK_PERIOD_NS/2) begin
        clk = ~clk;
    end
    
    initial begin
        #200;
        reset = 1'b0;
    end
    
    logic rx_li = 1'b1;
    logic tx;
    system #(.clk_per_bit_p(clk_per_bit_p)) dut
        (.sys_clk_i(clk)
         ,.reset_i(reset)
         ,.rx_i(rx_li)
         ,.tx_o(tx)
         );
    
    logic [7:0] data_byte = 8'b1010_0011;
    
    integer ii;
    initial begin
        #(ns_per_bit_p);
        rx_li = 1'b0;
        #(ns_per_bit_p);
        // send LSB->MSB
        for (ii = 0; ii < 8; ii = ii+1) begin
            rx_li = data_byte[ii];
            #(ns_per_bit_p);
        end
        rx_li = 1'b1;
        #(ns_per_bit_p * 20);
        $finish;
    end

endmodule
