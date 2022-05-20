
module renderer(
  input clk_sys,
  input [15:0] segA,
  input [15:0] segB,
  input [3:0] H,
  input Bs,

  output reg [24:0] rom_img_addr,
  output reg rom_img_read,
  input rom_img_data_ready,
  input [7:0] rom_img_data,

  output reg [27:0] fb_addr,
  output reg [63:0] fb_data,
  output reg fb_req,
  input fb_ready,

  input disp_en,
  output frame
);

parameter
  SETUP_MASK_READ = 4'd0,
  WAIT_FOR_MASK_DATA = 4'd1,
  READ_MASK_BYTE = 4'd2,
  SETUP_IMG_READ = 4'd3,
  WAIT_FOR_IMG_DATA = 4'd4,
  READ_IMG_BYTE = 4'd5,
  PUSH_FB_COLOR = 4'd6,
  WRITE_FB = 4'd7,
  WAIT_FOR_FB_WRITE = 4'd8,
  UPDATE_CACHE = 4'd9;

reg [3:0] state;

reg [7:0] fb_color;
reg [2:0] fb_count;

reg seg_en;
wire [1:0] id  = rom_img_data[7:6];
wire [3:0] col = rom_img_data[5:2];
wire [1:0] row = rom_img_data[1:0];

reg [15:0] seg_a[3:0];
reg [15:0] seg_b[3:0];
reg [3:0] seg_s;

reg [15:0] seg_a_cache[3:0];
reg [15:0] seg_b_cache[3:0];
reg [3:0] seg_s_cache;
reg [1:0] rh;


// update internal segment cache

always @*
  case (H)
    4'b0001: rh = 2'd0;
    4'b0010: rh = 2'd1;
    4'b0100: rh = 2'd2;
    4'b1000: rh = 2'd3;
  endcase

always @(posedge clk_sys) begin
  seg_a[rh] <= segA;
  seg_b[rh] <= segB;
  seg_s[rh] <= Bs;
end

// read internal segment cache

// enable part A and comment part B to activate cache (rendering should be fast enough)
// do the opposite to disable live rendering

// part A
always @* begin
  seg_en = 1'b0;
  case (id)
    2'd0: seg_en = seg_a_cache[row][col];
    2'd1: seg_en = seg_b_cache[row][col];
    2'd2: seg_en = seg_s_cache[row];
  endcase
end

// part B
/*
always @* begin
  seg_en = 1'b0;
  case (id)
    2'd0: seg_en = seg_a[row][col];
    2'd1: seg_en = seg_b[row][col];
    2'd2: seg_en = seg_s[row];
  endcase
end
*/
// end of part B

// 720x480

parameter IMG_SIZE = 720*480;
assign frame = px == IMG_SIZE;
reg [18:0] px;
reg [1:0] pause = 2'd3;
reg inc;

always @(posedge clk_sys) begin

  if (disp_en) begin

    case (state)

      SETUP_MASK_READ: begin
        rom_img_read <= 1'b1;
        state <= rom_img_data_ready ? pause == 2'd0 ? WAIT_FOR_MASK_DATA : SETUP_MASK_READ : WAIT_FOR_MASK_DATA;
        pause <= pause - 2'd1;
      end

      WAIT_FOR_MASK_DATA: begin
        state <= rom_img_data_ready ? READ_MASK_BYTE : WAIT_FOR_MASK_DATA;
        rom_img_read <= 1'b0;
      end

      READ_MASK_BYTE: begin
        inc <= seg_en;
        rom_img_addr <= rom_img_addr + (seg_en ? 25'd1 : 25'd2);
        state <= SETUP_IMG_READ;
      end

      SETUP_IMG_READ: begin
        rom_img_read <= 1'b1;
        state <= rom_img_data_ready ? pause == 2'd0 ? WAIT_FOR_IMG_DATA : SETUP_IMG_READ : WAIT_FOR_IMG_DATA;
        pause <= pause - 2'd1;
      end

      WAIT_FOR_IMG_DATA: begin
        state <= rom_img_data_ready ? READ_IMG_BYTE : WAIT_FOR_IMG_DATA;
        rom_img_read <= 1'b0;
      end

      READ_IMG_BYTE: begin
        fb_color <= rom_img_data;
        fb_count <= fb_count + 3'd1;
        state <= PUSH_FB_COLOR;
      end

      PUSH_FB_COLOR: begin
        px <= px + 19'd1;
        rom_img_addr <= rom_img_addr + (inc ? 25'd2 : 25'd1);
        fb_data <= { fb_color, fb_data[63:8] };
        state <= fb_count == 3'd0 ? WRITE_FB : UPDATE_CACHE;
      end

      WRITE_FB: begin
        fb_req <= 1'b1;
        state <= fb_ready ? WRITE_FB : WAIT_FOR_FB_WRITE;
      end

      WAIT_FOR_FB_WRITE: begin
        if (fb_ready) begin
          state <= UPDATE_CACHE;
          fb_addr[27:3] <= fb_addr[27:3] + 28'd1;
        end
        else begin
          state <= WAIT_FOR_FB_WRITE;
        end
        fb_req <= 1'b0;
      end

      // update coordinates
      UPDATE_CACHE: begin

        if (frame) begin
          fb_addr <= 28'd0;
          rom_img_addr <= 25'd0;
          px <= 19'd0;
          seg_a_cache[0] <= seg_a[0];
          seg_a_cache[1] <= seg_a[1];
          seg_a_cache[2] <= seg_a[2];
          seg_a_cache[3] <= seg_a[3];
          seg_b_cache[0] <= seg_b[0];
          seg_b_cache[1] <= seg_b[1];
          seg_b_cache[2] <= seg_b[2];
          seg_b_cache[3] <= seg_b[3];
          seg_s_cache <= seg_s;
        end

        state <= SETUP_MASK_READ;

      end

    endcase

  end

end


endmodule
