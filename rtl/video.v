
module video(

  input clk_vid,

  output ce_pxl,

  output hsync,
  output vsync,
  output hblank,
  output vblank,
  output reg [7:0] red,
  output reg [7:0] green,
  output reg [7:0] blue,

  output [18:0] addr,
  input [15:0] din

);

reg [9:0] hcount;
reg [9:0] vcount;

// Timing for 640 x 480 @ 60 Hz (25.175 MHz)

parameter HFP = 640;    // front porch
parameter HSP = HFP+16; // sync pulse
parameter HBP = HSP+96; // back porch
parameter HWL = HBP+48; // whole line
parameter VFP = 480;    // front porch
parameter VSP = VFP+10; // sync pulse
parameter VBP = VSP+2;  // back porch
parameter VWL = VBP+33; // whole line

assign hsync = ~((hcount >= HSP) && (hcount < HBP));
assign vsync = ~((vcount >= VSP) && (vcount < VBP));

assign hblank = hcount >= HFP;
assign vblank = vcount >= VFP;
assign ce_pxl = hcount[0] == 1;

assign addr = vcount * 10'd640 + hcount;


always @(posedge clk_vid)
  { red, green, blue } <= { { din[7:5], 5'd0 }, { din[4:2], 5'd0 }, { din[1:0], 6'd0 } };


always @(posedge clk_vid) begin
  hcount <= hcount + 10'd1;
  if (hcount == HWL) hcount <= 0;
end

always @(posedge clk_vid)
  if (hcount == HWL)
    vcount <= vcount + 10'd1;
  else if (vcount == VWL)
    vcount <= 0;


endmodule