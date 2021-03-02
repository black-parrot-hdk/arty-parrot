`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/01/2021 11:24:15 AM
// Design Name: 
// Module Name: uart_tx
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

`include "uart_defs.vh"

module uart_tx
    #(parameter clk_per_bit_p = 10416 // 100 MHz clock, 9600 Baud
    )
    (input clk_i
    , input reset_i
    , input tx_v_i
    , input [7:0] tx_i
    , output logic tx_v_o
    , output logic tx_o
    , output logic tx_done_o
    );
        
    typedef enum logic [2:0] {
        e_reset
        , e_idle
        , e_start_bit
        , e_data_bits
        , e_stop_bit
        , e_finish
    } state_e;
    state_e tx_state_r, tx_state_n;
    
    logic [15:0] clk_cnt_r, clk_cnt_n;
    logic [`SAFE_CLOG2(7)-1:0] data_cnt_r, data_cnt_n;
    
    // transmit LSB->MSB
    logic [7:0] tx_data_r, tx_data_n;
    logic tx_r, tx_n;
    logic tx_v_r, tx_v_n;
    logic tx_done_r, tx_done_n;
    
    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            tx_state_r <= e_reset;
            clk_cnt_r <= '0;
            data_cnt_r <= '0;
            tx_data_r <= '0;
            tx_r <= 1'b1;
            tx_v_r <= '0;
            tx_done_r <= '0;
        end else begin
            tx_state_r <= tx_state_n;
            clk_cnt_r <= clk_cnt_n;
            data_cnt_r <= data_cnt_n;
            tx_data_r <= tx_data_n;
            tx_r <= tx_n;
            tx_v_r <= tx_v_n;
            tx_done_r <= tx_done_n;
        end
    end
    
    always_comb begin
        // state
        tx_state_n = tx_state_r;
        
        tx_data_n = tx_data_r;
        tx_n = tx_r;
        tx_v_n = tx_v_r;
        tx_done_n = tx_done_r;
        
        // outputs
        tx_o = tx_r;
        tx_v_o = tx_v_r;
        tx_done_o = tx_done_r;
        
        clk_cnt_n = clk_cnt_r;
        data_cnt_n = data_cnt_r;
        
        case (tx_state_r)
            e_reset: begin
                tx_state_n = e_idle;
            end
            e_idle: begin
                tx_n = 1'b1;
                tx_v_n = '0;
                tx_done_n = '0;
                clk_cnt_n = '0;
                data_cnt_n = '0;
                if (tx_v_i == 1'b1) begin
                    tx_v_n = 1'b1;
                    tx_data_n = tx_i;
                    tx_state_n = e_start_bit;
                end
            end
            e_start_bit: begin
                tx_n = 1'b0;
                if (clk_cnt_r < clk_per_bit_p-1) begin
                    clk_cnt_n = clk_cnt_r + 'd1;
                end else begin
                    clk_cnt_n = '0;
                    tx_state_n = e_data_bits;
                end
            end
            e_data_bits: begin
                tx_n = tx_data_r[data_cnt_r];
                if (clk_cnt_r < clk_per_bit_p-1) begin
                    clk_cnt_n = clk_cnt_r + 'd1;
                end else begin
                    clk_cnt_n = '0;
                    if (data_cnt_r < 7) begin
                        data_cnt_n = data_cnt_r + 'd1;
                    end else begin
                        data_cnt_n = '0;
                        tx_state_n = e_stop_bit;
                    end
                end
            end
            e_stop_bit: begin
                tx_n = 1'b1;
                if (clk_cnt_r < clk_per_bit_p-1) begin
                    clk_cnt_n = clk_cnt_r + 'd1;
                end else begin
                    clk_cnt_n = '0;
                    tx_done_n = 1'b1;
                    tx_v_n = 1'b0;
                    tx_state_n = e_finish;
                end
            end
            e_finish: begin
                tx_done_n = 1'b1;
                tx_state_n = e_idle;
            end
            default: begin
                tx_state_n = e_reset;
            end
        endcase
    end
        
endmodule
