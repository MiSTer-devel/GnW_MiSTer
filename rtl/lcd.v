
module lcd(
  input clk,
  output reg [18:0] lcd_addr,
  output reg [7:0] lcd_dout,
  output reg lcd_vram_we,

  output reg [24:0] sdram_addr,
  input [7:0] sdram_data,
  output reg sdram_rd,

  input [15:0] segA,
  input [15:0] segB,
  input Bs,
  input [3:0] H,

  input rdy
);


reg [2:0] state;
reg seg_en;

wire [1:0]  id = sdram_data[7:6];
wire [3:0] col = sdram_data[5:2];
wire [1:0] row = sdram_data[1:0];

reg [24:0] old_sdram_addr;

always @* begin
  seg_en = 1'b0;
  case (id)
    2'd0: seg_en = seg_a_cache[row][col];
	 2'd1: seg_en = seg_b_cache[row][col];
	 2'd2: seg_en = seg_s_cache[row];
  endcase
end


reg [15:0] seg_a_cache[3:0];
reg [15:0] seg_b_cache[3:0];
reg [1:0]  seg_s_cache;
reg [1:0] rh;

always @*
  case (H)
    4'b0001: rh = 2'd0;
	 4'b0010: rh = 2'd1;
	 4'b0100: rh = 2'd2;
	 4'b1000: rh = 2'd3;
  endcase

always @(posedge clk) begin
  seg_a_cache[rh] <= segA;
  seg_b_cache[rh] <= segB;
  seg_s_cache[rh] <= Bs;
end

always @(posedge clk)
	if (rdy)
		case (state)

			3'b000: begin // init
				lcd_addr <= 0;
				state <= 3'b001;
				sdram_addr <= 640*480;
			end

			3'b001: begin // prepare sdram read mask pxl
			  sdram_rd <= 1'b1;
			  sdram_addr <= sdram_addr + 25'd1;
			  state <= 3'b010;
			end

			3'b010: begin
				sdram_rd <= 1'b0;
				old_sdram_addr <= sdram_addr;

				// if it's a segment pixel and status is on
				// write 0 to vram
				if (seg_en) begin
				  lcd_vram_we <= 1'b1;
				  lcd_addr <= sdram_addr - 640*480;
				  lcd_dout <= 8'd0;
				  state <= 3'b001; // then read next mask pxl
				end
				else begin
				  state <= 3'b011; // if bg or segment is off read bg color
				end

				if (sdram_addr >= 2*640*480) begin // end? go back to init
					state <= 3'b000;
				end

			end

			3'b011: begin // setup bg read
				sdram_rd <= 1'b1;
				sdram_addr <= old_sdram_addr - 640*480; // point to bg
				state <= 3'b100;
			end

			3'b100: begin // read bg color
			  lcd_vram_we <= 1'b1;
			  lcd_addr <= sdram_addr;
			  lcd_dout <= sdram_data;
			  sdram_rd <= 1'b0;
			  sdram_addr <= sdram_addr + 640*480; // fix addr
			  if (sdram_addr >= 640*480) begin // end, go back to init
			    state <= 3'b000;
			  end
			  else begin // continue reading mask
				 state <= 3'b001;
			  end
			end

		endcase



endmodule