
module video(

  input clk_vid,

  output hsync,
  output vsync,
  output hblank,
  output vblank,

  output [10:0] hpos,
  output [9:0] vpos

);

assign hpos = hcount;
assign vpos = vcount;

reg [10:0] hcount;
reg [9:0] vcount;


parameter HFP = 800;    // front porch
parameter HSP = HFP+24; // sync pulse
parameter HBP = HSP+72; // back porch
parameter HWL = HBP+128; // whole line
parameter VFP = 600;    // front porch
parameter VSP = VFP+1; // sync pulse
parameter VBP = VSP+2;  // back porch
parameter VWL = VBP+22; // whole line

assign hsync = ~((hcount >= HSP) && (hcount < HBP));
assign vsync = ~((vcount >= VSP) && (vcount < VBP));

assign hblank = hcount >= HFP;
assign vblank = vcount >= VFP;

always @(posedge clk_vid) begin
  hcount <= hcount + 11'd1;
  if (hcount == HWL) hcount <= 0;
end

always @(posedge clk_vid) begin
  if (hcount == HWL) begin
    if (vcount == VWL)
      vcount <= 0;
    else
      vcount <= vcount + 10'd1;
  end
end


endmodule