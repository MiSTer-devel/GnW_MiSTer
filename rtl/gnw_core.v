
module gnw_core(
  input reset,
  input clk_sys,
  input clk_vid,

  input [24:0] ioctl_addr,
  input ioctl_download,
  input [7:0] ioctl_dout,

  output [1:0] melody,
  input [31:0] joy,

  output [7:0] red,
  output [7:0] green,
  output [7:0] blue,
  output hsync,
  output vsync,
  output hblank,
  output vblank,

  output [24:0] sdram_addr,
  input [15:0] sdram_data,
  output sdram_rd

);

wire [24:0] rom_rel_addr;
reg [24:0] rom_img_addr;
wire [24:0] sdram_raw_addr;
assign sdram_addr = sdram_raw_addr + rom_img_addr;

wire [15:0] segA;
wire [15:0] segB;
wire Bs;

wire [3:0] H;
wire [7:0] S;

wire [9:0] hpos, vpos;

///// config

reg [7:0] mcuid;
reg [7:0] joy_config[11:0];
always @(posedge clk_sys) begin
  if (id) mcuid <= ioctl_dout;
  if (conf) joy_config[rom_rel_addr] <= ioctl_dout;
end

// 0:right, 1:left, 2:down, 3:up
// 4:jump, 5:time, 6:gameA, 7:gameB
// 8:alarm, 9:action1, 10:action2, 11:action3
// 15:none

reg [3:0] joy_conf_addr;
always @(posedge clk_sys)
  case(S)
    8'b00000001: joy_conf_addr <= 4'd0;
    8'b00000010: joy_conf_addr <= 4'd2;
    8'b00000100: joy_conf_addr <= 4'd4;
    8'b00001000: joy_conf_addr <= 4'd6;
    8'b00010000: joy_conf_addr <= 4'd8;
    8'b00100000: joy_conf_addr <= 4'd10;
    8'b01000000: joy_conf_addr <= 4'd12;
  endcase

wire [3:0] K = { joy[jc2[3:0]], joy[jc2[7:4]], joy[jc1[3:0]], joy[jc1[7:4]] };
reg [7:0] jc1, jc2;
always @(posedge clk_sys) begin
  jc1 <= joy_config[joy_conf_addr];
  jc2 <= joy_config[joy_conf_addr+1];
end

reg new_img_status;
always @(posedge clk_sys) begin
  new_img_status <= image;
  if (new_img_status ^ image && image) rom_img_addr <= ioctl_addr;
end


/////

wire id, conf, image, palette, rom;
rom_decode rom_decode(
  .clk_sys(clk_sys),
  .ioctl_addr(ioctl_addr),
  .ioctl_download(ioctl_download),
  .ioctl_dout(ioctl_dout),
  .relative_addr(rom_rel_addr),
  .id(id),
  .conf(conf),
  .image(image),
  .palette(palette),
  .rom(rom)
);


reg [7:0] romd;//, romdd;
//reg [11:0] roma;
always @(posedge clk_sys) begin
  romd <= ioctl_dout;
//  romd <= romdd;
//  roma <= rom_rel_addr;
end


SM510 mcu(
  //.mod(mcuid),

  .rst(reset),
  .clk(clk_sys),

  .rom_init(rom),
  .rom_init_data(romd),
  .rom_init_addr(rom_rel_addr),

  .K(K),
  .Beta(1),
  .BA(1),
  .segA(segA),
  .segB(segB),
  .Bs(Bs),

  .R(melody),
  .H(H),
  .S(S),

  .dbg(LED_USER)
);

video video(
  .clk_vid(clk_lcd),
  .hsync(hsync),
  .vsync(vsync),
  .hblank(hblank),
  .vblank(vblank),
  .hpos(hpos),
  .vpos(vpos)
);


reg clk_lcd;
reg [1:0] clk_cnt;
always @(posedge clk_vid) begin
  clk_lcd <= 1'b0;
  clk_cnt <= clk_cnt + 2'd1;
  if (clk_cnt == 2'd1) begin
    clk_lcd <= 1'b1;
    clk_cnt <= 2'd0;
  end
end

// always @(posedge clk_vid)
//   clk_lcd <= ~clk_lcd;

lcd lcd(
  .clk_lcd(clk_lcd),
  .clk(clk_sys),
  .hpos(hpos),
  .vpos(vpos),
  .red(red),
  .green(green),
  .blue(blue),
  .pal_load(palette),
  .pal_addr(rom_rel_addr),
  .pal_din(ioctl_dout),
  .sdram_addr(sdram_raw_addr),
  .sdram_data(sdram_data),
  .sdram_rd(sdram_rd),
  .segA(segA),
  .segB(segB),
  .Bs(Bs),
  .H(H),
  .rdy(~ioctl_download)
);


endmodule