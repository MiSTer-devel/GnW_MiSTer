
module lcd(
  input clk_lcd,
  input clk,

  input [10:0] hpos,
  input [9:0] vpos,

  output [7:0] red,
  output [7:0] green,
  output [7:0] blue,

  output reg [24:0] sdram_addr,
  input [15:0] sdram_data,
  output reg sdram_rd,

  input pal_load,
  input [9:0] pal_addr,
  input [7:0] pal_din,

  input [15:0] segA,
  input [15:0] segB,
  input Bs,
  input [3:0] H,

  input rdy
);

reg [2:0] state;
reg seg_en;
reg [1:0]  id;
reg [3:0] col;
reg [1:0] row;
reg [7:0] cid;

reg [15:0] seg_a_cache[3:0];
reg [15:0] seg_b_cache[3:0];
reg [1:0] seg_s_cache;
reg [1:0] rh;

reg [18:0] prev_video_addr;
wire [18:0] video_addr = vpos * 10'd800 + hpos;
wire [24:0] pxaddr = video_addr * 2;

// update internal segment cache

always @*
  case (H)
    4'b0001: rh = 2'd0;
    4'b0010: rh = 2'd1;
    4'b0100: rh = 2'd2;
    4'b1000: rh = 2'd3;
	 default: rh = 2'd0;
  endcase

always @(posedge clk) begin
  seg_a_cache[rh] <= segA;
  seg_b_cache[rh] <= segB;
  seg_s_cache[rh] <= Bs;
end

// read internal segment cache

always @* begin
  seg_en = 1'b0;
  case (id)
    2'd0: seg_en = seg_a_cache[row][col];
    2'd1: seg_en = seg_b_cache[row][col];
    2'd2: seg_en = seg_s_cache[row];
  endcase
end

// palette - async ram

reg [7:0] palette[255*3:0];
wire [9:0] palette_color_addr = cid * 3;
assign red = seg_en ? 8'd0 : palette[palette_color_addr];
assign green = seg_en ? 8'd0 : palette[palette_color_addr+1];
assign blue = seg_en ? 8'd0 : palette[palette_color_addr+2];

always @(posedge clk)
  if (pal_load)
    palette[pal_addr] <= pal_din;

// read 16bit from sdram

always @(posedge clk_lcd)
	if (rdy) begin
    prev_video_addr <= video_addr;
    case (state)
      3'd0: begin
        state <= 3'd0;
        if (prev_video_addr ^ video_addr) begin
          state <= 3'd1;
          sdram_addr <= pxaddr;
          sdram_rd <= 1'b1;
        end
      end
      3'd1: begin
        sdram_rd <= 1'b0;
        state <= 3'd2;
        cid <= sdram_data[15:8];
        id <= sdram_data[7:6];
        col <= sdram_data[5:2];
        row <= sdram_data[1:0];
        state <= 3'd0;
      end
    endcase
  end

/*
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




//


parameter
  WAIT = 3'd0,
  COLOR = 3'd1,
  RAM_WAIT_HBL  = 2'd0,
  RAM_START     = 2'd1,
  RAM_READ      = 2'd2,
  RAM_WAIT_DATA = 2'd3;

wire [18:0] video_addr = (vpos+1) * 10'd640 + hpos;

// bram scanline cache
reg [31:0] scanline [639:0];
reg [9:0] pxlcnt;
wire [9:0] nxtpxl = pxlcnt + 10'd1;
reg [1:0] ddram_state;

always @(posedge clk) begin
  case (ddram_state)
      RAM_WAIT_HBL: begin
        ddram_state <= hpos == 640 ? RAM_START : RAM_WAIT_HBL;
      end
      RAM_START: begin
        pxlcnt <= 10'd0;
        ddram_addr <= pxaddr;
        ddram_rd <= 1'b1;
        ddram_state <= RAM_WAIT_DATA;
      end
      RAM_READ: begin
        pxlcnt <= pxlcnt + 10'd2;
        ddram_addr <= ddram_addr + 28'd8;
        ddram_rd <= 1'b1;
        ddram_state <= RAM_WAIT_DATA;
      end
      RAM_WAIT_DATA: begin
        ddram_state <= RAM_WAIT_DATA;
        if (ddram_ready) begin
          ddram_rd <= 1'b0;
          scanline[pxlcnt] <= ddram_data[63:32];
          scanline[nxtpxl] <= ddram_data[31:0];
          ddram_state <= nxtpxl >= 639 ? RAM_WAIT_HBL : RAM_READ;
        end
      end
  endcase
end

reg [9:0] new_hpos;
always @(posedge clk)
  if (rdy) begin
    new_hpos <= hpos;
    case (state)
      WAIT: begin
        state <= WAIT;
        if (new_hpos ^ hpos) begin
          id <= scanline[hpos][31:30];
          col <= scanline[hpos][29:26];
          row <= scanline[hpos][25:24];
          red <= scanline[hpos][23:16];
          green <= scanline[hpos][15:8];
          blue <= scanline[hpos][7:0];
          state <= COLOR;
        end
      end
      COLOR: begin
        state <= WAIT;
        if (seg_en) begin
          red <= 8'd0;
          green <= 8'd0;
          blue <= 8'd0;
        end
      end
    endcase
  end
*/

endmodule