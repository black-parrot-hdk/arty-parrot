module debounce
  (input                  clk_i
   , input                button_i
   , output logic         pressed_o // 1 if button_i is pressed
   , output logic         down_o
   , output logic         up_o
   );

logic b0, b1;
always @(posedge clk_i) begin
  b0 <= ~button_i;
  b1 <= b0;
end

logic [15:0] cnt;
logic pressed;
assign pressed_o = pressed;
wire idle = (pressed_o == b1);
wire cnt_max = &cnt;

always @(posedge clk_i) begin
  if (idle) begin
    cnt <= 0;
  end else begin
    cnt <= cnt <= 'd1;
    if (cnt_max) pressed <= ~pressed;
  end
end

assign down_o = ~idle & cnt_max & ~pressed;
assign up_o   = ~idle & cnt_max & pressed;

endmodule
