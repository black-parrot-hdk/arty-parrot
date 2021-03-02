`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/01/2021 11:24:15 AM
// Design Name: 
// Module Name: uart_rx
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

module uart_rx
    #(parameter clk_per_bit_p = 10416 // 100 MHz clock, 9600 Baud
    )
    (input clk_i
    , input reset_i
    // LSB->MSB
    , input rx_i
    , output logic rx_v_o
    , output logic [7:0] rx_o
    );
    
    typedef enum logic [2:0] {
        e_reset
        , e_idle
        , e_start_bit
        , e_data_bits
        , e_stop_bit
        , e_finish
    } state_e;
    state_e rx_state_r, rx_state_n;
    
    logic [15:0] clk_cnt_r, clk_cnt_n;
    logic [`SAFE_CLOG2(7)-1:0] data_cnt_r, data_cnt_n;
    
    logic data_in_r, data_in_n;
    logic data_r, data_n;
    wire rx_start = (data_r == 1'b0);
    wire rx_stop = (data_r == 1'b1);
    
    logic [7:0] rx_data_r, rx_data_n;
    logic rx_v_r, rx_v_n;
    
    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            rx_state_r <= e_reset;
            clk_cnt_r <= '0;
            data_cnt_r <= '0;
            data_in_r <= '0;
            data_r <= '0;
            rx_data_r <= '0;
            rx_v_r <= '0;
        end else begin
            rx_state_r <= rx_state_n;
            clk_cnt_r <= clk_cnt_n;
            data_cnt_r <= data_cnt_n;
            data_in_r <= data_in_n;
            data_r <= data_n;
            rx_data_r <= rx_data_n;
            rx_v_r <= rx_v_n;
        end
    end
    
    always_comb begin
        // state
        rx_state_n = rx_state_r;
        
        // outputs
        rx_o = rx_data_r;
        rx_v_o = rx_v_r;
        
        // input and data buffering
        // rx_i -> data_in_r -> data_r
        data_in_n = rx_i;
        data_n = data_in_r;
        
        // rx valid and data registers
        rx_v_n = rx_v_r;
        rx_data_n = rx_data_r;

        // clock and data counters
        clk_cnt_n = clk_cnt_r;
        data_cnt_n = data_cnt_r;
        
        case (rx_state_r)
            e_reset: begin
                rx_state_n = e_idle;
            end
            e_idle: begin
                clk_cnt_n = '0;
                data_cnt_n = '0;
                rx_v_n = '0;
                rx_data_n = '0;
                rx_state_n = rx_start ? e_start_bit : e_idle;
            end
            e_start_bit: begin
                if (clk_cnt_r == (clk_per_bit_p-1)/2) begin
                    if (data_r == 1'b0) begin
                        clk_cnt_n = '0;
                        rx_state_n = e_data_bits;
                    end else begin
                        rx_state_n = e_idle;
                    end
                end else begin
                    clk_cnt_n = clk_cnt_r + 'd1;
                end
            end
            e_data_bits: begin
                if (clk_cnt_r == (clk_per_bit_p - 'd1)) begin
                    clk_cnt_n = '0;
                    rx_data_n[data_cnt_r] = data_r;
                    if (data_cnt_r < 7) begin
                        data_cnt_n = data_cnt_r + 'd1;
                    end else begin
                        data_cnt_n = '0;
                        rx_state_n = e_stop_bit;
                    end
                end else begin
                    clk_cnt_n = clk_cnt_r + 'd1;
                end
            end
            e_stop_bit: begin
                if (clk_cnt_r == (clk_per_bit_p - 'd1)) begin
                    rx_v_n = 1'b1;
                    clk_cnt_n = '0;
                    rx_state_n = e_finish;
                end else begin
                    clk_cnt_n = clk_cnt_r + 'd1;
                end
            end
            e_finish: begin
                rx_state_n = e_idle;
                rx_v_n = '0;
            end
            default: begin
                rx_state_n = e_reset; 
            end
        endcase
    end
    
endmodule
