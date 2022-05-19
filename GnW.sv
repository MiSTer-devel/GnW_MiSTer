//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
  //Master input clock
  input         CLK_50M,

  //Async reset from top-level module.
  //Can be used as initial reset.
  input         RESET,

  //Must be passed to hps_io module
  inout  [48:0] HPS_BUS,

  //Base video clock. Usually equals to CLK_SYS.
  output        CLK_VIDEO,

  //Multiple resolutions are supported using different CE_PIXEL rates.
  //Must be based on CLK_VIDEO
  output        CE_PIXEL,

  //Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
  //if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
  output [12:0] VIDEO_ARX,
  output [12:0] VIDEO_ARY,

  output  [7:0] VGA_R,
  output  [7:0] VGA_G,
  output  [7:0] VGA_B,
  output        VGA_HS,
  output        VGA_VS,
  output        VGA_DE,    // = ~(VBlank | HBlank)
  output        VGA_F1,
  output [1:0]  VGA_SL,
  output        VGA_SCALER, // Force VGA scaler

  input  [11:0] HDMI_WIDTH,
  input  [11:0] HDMI_HEIGHT,
  output        HDMI_FREEZE,

`ifdef MISTER_FB
  // Use framebuffer in DDRAM (USE_FB=1 in qsf)
  // FB_FORMAT:
  //    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
  //    [3]   : 0=16bits 565 1=16bits 1555
  //    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
  //
  // FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
  output        FB_EN,
  output  [4:0] FB_FORMAT,
  output [11:0] FB_WIDTH,
  output [11:0] FB_HEIGHT,
  output [31:0] FB_BASE,
  output [13:0] FB_STRIDE,
  input         FB_VBL,
  input         FB_LL,
  output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
  // Palette control for 8bit modes.
  // Ignored for other video modes.
  output        FB_PAL_CLK,
  output  [7:0] FB_PAL_ADDR,
  output [23:0] FB_PAL_DOUT,
  input  [23:0] FB_PAL_DIN,
  output        FB_PAL_WR,
`endif
`endif

  output        LED_USER,  // 1 - ON, 0 - OFF.

  // b[1]: 0 - LED status is system status OR'd with b[0]
  //       1 - LED status is controled solely by b[0]
  // hint: supply 2'b00 to let the system control the LED.
  output  [1:0] LED_POWER,
  output  [1:0] LED_DISK,

  // I/O board button press simulation (active high)
  // b[1]: user button
  // b[0]: osd button
  output  [1:0] BUTTONS,

  input         CLK_AUDIO, // 24.576 MHz
  output [15:0] AUDIO_L,
  output [15:0] AUDIO_R,
  output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
  output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

  //ADC
  inout   [3:0] ADC_BUS,

  //SD-SPI
  output        SD_SCK,
  output        SD_MOSI,
  input         SD_MISO,
  output        SD_CS,
  input         SD_CD,

`ifdef USE_DDRAM
  //High latency DDR3 RAM interface
  //Use for non-critical time purposes
  output        DDRAM_CLK,
  input         DDRAM_BUSY,
  output  [7:0] DDRAM_BURSTCNT,
  output [28:0] DDRAM_ADDR,
  input  [63:0] DDRAM_DOUT,
  input         DDRAM_DOUT_READY,
  output        DDRAM_RD,
  output [63:0] DDRAM_DIN,
  output  [7:0] DDRAM_BE,
  output        DDRAM_WE,
`endif

  //SDRAM interface with lower latency
  output        SDRAM_CLK,
  output        SDRAM_CKE,
  output [12:0] SDRAM_A,
  output  [1:0] SDRAM_BA,
  inout  [15:0] SDRAM_DQ,
  output        SDRAM_DQML,
  output        SDRAM_DQMH,
  output        SDRAM_nCS,
  output        SDRAM_nCAS,
  output        SDRAM_nRAS,
  output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
  //Secondary SDRAM
  //Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
  input         SDRAM2_EN,
  output        SDRAM2_CLK,
  output [12:0] SDRAM2_A,
  output  [1:0] SDRAM2_BA,
  inout  [15:0] SDRAM2_DQ,
  output        SDRAM2_nCS,
  output        SDRAM2_nCAS,
  output        SDRAM2_nRAS,
  output        SDRAM2_nWE,
`endif

  input         UART_CTS,
  output        UART_RTS,
  input         UART_RXD,
  output        UART_TXD,
  output        UART_DTR,
  input         UART_DSR,

  // Open-drain User port.
  // 0 - D+/RX
  // 1 - D-/TX
  // 2..6 - USR2..USR6
  // Set USER_OUT to 1 to read from USER_IN.
  input   [6:0] USER_IN,
  output  [6:0] USER_OUT,

  input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
// assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
// assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;

assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER = 0;
assign HDMI_FREEZE = 0;

assign AUDIO_S = 0;
assign AUDIO_L = { melody[0], 15'd0 };
assign AUDIO_R = { melody[0], 15'd0 };
assign AUDIO_MIX = 2'd3;

assign LED_DISK = ioctl_download;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[9:8];

assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;


`include "build_id.v"
localparam CONF_STR = {
  "Game & Watch;;",
  "-;",
  "O89,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
  "-;",
  "F,BIN,Load File;",
  "-;",
  "R0,Reset;",
  "-;",
  "J,jump,time,A,B,alarm;",
  "V,v",`BUILD_DATE
};


wire forced_scandoubler;
wire  [1:0] buttons;
wire [31:0] status;
wire [10:0] ps2_key;
wire [15:0] j0;

wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        ioctl_download;
wire  [7:0] ioctl_index;
wire		ioctl_wait;

wire [64:0] RTC;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
  .clk_sys(clk_sys),
  .HPS_BUS(HPS_BUS),
  .EXT_BUS(),
  .gamma_bus(),

  .forced_scandoubler(forced_scandoubler),

  .joystick_0(j0),

  .buttons(buttons),
  .status(status),
  .status_menumask({status[5]}),

  .ps2_key(ps2_key),

  .ioctl_download(ioctl_download),
  .ioctl_wr(ioctl_wr),
  .ioctl_addr(ioctl_addr),
  .ioctl_dout(ioctl_dout),
  .ioctl_wait(ioctl_wait),
  .ioctl_index(ioctl_index),

  .RTC(RTC)
);


///////////////////////   CLOCKS   ///////////////////////////////

wire locked;
wire clk_sys, clk_27;

pll pll
(
  .refclk(CLK_50M),
  .rst(0),
  .outclk_0(clk_sys), // 50
  .outclk_1(clk_27), // 25
  .locked(locked)
);

wire reset = RESET | status[0] | buttons[1] | ioctl_download;

//////////////////////////////////////////////////////////////////

// VIDEO

wire hblank, hsync;
wire vblank, vsync;
wire ce_pix;
assign VGA_DE = ~(hblank|vblank);
assign VGA_HS = hsync;
assign VGA_VS = vsync;
assign CLK_VIDEO = clk_27;
assign CE_PIXEL = 1'b1;

hvgen hvgen(
  .vclk(clk_27),
  .hb(hblank),
  .vb(vblank),
  .hs(hsync),
  .vs(vsync),
  .ce_pix(ce_pix),
  .hcnt(), // NC
  .vcnt()  // NC
);

////////////// CONFIG /////////////

wire [7:0] mcuid;
wire [24:0] rom_base_image_addr;
wire [24:0] rom_base_addr;
wire conf_load, pal_load, rom_load;
reg [7:0] jc1, jc2;
reg [3:0] joy_conf_addr;

reg [7:0] conf[127:0];
wire [3:0] K = { j0[jc2[3:0]], j0[jc2[7:4]], j0[jc1[3:0]], j0[jc1[7:4]] };

rom_decode rom_decode(
  .clk_sys(clk_sys),

  .ioctl_addr(ioctl_addr),
  .ioctl_download(ioctl_download),
  .ioctl_dout(ioctl_dout),

  .conf(conf_load),
  .palette(pal_load),
  .rom(rom_load),

  .mcuid(mcuid),
  .image_addr(rom_base_image_addr),
  .rom_addr(rom_base_addr)
);

always @(posedge clk_sys)
  if (S[0]) joy_conf_addr <= 4'd1;
  else if (S[1]) joy_conf_addr <= 4'd3;
  else if (S[2]) joy_conf_addr <= 4'd5;
  else if (S[3]) joy_conf_addr <= 4'd7;
  else if (S[4]) joy_conf_addr <= 4'd9;
  else if (S[5]) joy_conf_addr <= 4'd11;
  else if (S[6]) joy_conf_addr <= 4'd13;

always @(posedge clk_sys) begin
  jc1 <= conf[joy_conf_addr];
  jc2 <= conf[joy_conf_addr+1];
end


always @(posedge clk_sys) begin
  if (conf_load & ioctl_wr) begin
    conf[ioctl_addr-2] <= ioctl_dout;
  end
end

/////////// PALETTE //////////

assign FB_PAL_CLK = clk_sys;
assign FB_PAL_ADDR = pal_addr;
assign FB_PAL_DOUT = pal_color;
assign FB_PAL_WR = pal_wr;

reg old_ioctl_download;
reg [7:0] pal_addr = 8'd0;
reg [23:0] pal_color;
reg [1:0] pal_ch_cnt;
reg pal_wr;
reg [7:0] color;

always @(posedge clk_sys) begin

  old_ioctl_download <= ioctl_download;
  color <= ioctl_dout;

  if (~old_ioctl_download & ioctl_download) begin
    pal_addr <= 8'd0;
    pal_ch_cnt <= 2'd0;
    pal_wr <= 1'b0;
  end

  if (pal_load & ioctl_wr) begin

    if (pal_wr) pal_addr <= pal_addr + 8'd1;

    pal_wr <= 1'b0;
    pal_color <= { pal_color[15:0], color };
    pal_ch_cnt <= pal_ch_cnt + 2'd1;

    if (pal_ch_cnt == 2'd2) begin

      pal_ch_cnt <= 2'd0;
      pal_wr <= 1'b1;

    end

  end
end

///////////// RENDERING //////////

wire [24:0] rom_img_addr;
wire rom_img_read;
wire rom_img_data_ready = sdram_rdy;
wire frame;

renderer renderer(
  .clk_sys(clk_sys),

  .segA(segA),
  .segB(segB),
  .Bs(Bs),
  .H(H),

  .rom_img_addr(rom_img_addr),
  .rom_img_read(rom_img_read),
  .rom_img_data_ready(rom_img_data_ready),
  .rom_img_data(sdram_data),

  .fb_addr(fb_addr),
  .fb_data(fb_data),
  .fb_req(fb_req),
  .fb_ready(fb_ready),

  .disp_en(~reset),
  .frame(frame)
);

///////////// MCU ///////////////

wire [1:0] melody;
wire [7:0] S;
wire [11:0] mcu_rom_addr;
wire [6:0] mcu_ram_addr;
wire [7:0] rom_data;
wire rom_read;
wire [3:0] mcu_ram_dout;
wire [3:0] mcu_ram_din;
wire mcu_ram_wr;
wire [15:0] segA, segB;
wire [3:0] H;
wire Bs;

SM510 mcu(

  .rst(reset),
  .clk(clk_sys),

  .rom_init(rom_load & ioctl_wr),
  .rom_init_addr(ioctl_addr - rom_base_addr),
  .rom_init_data(ioctl_dout),
  .hms(RTC[23:0]),
  .hms_loc(conf[0]),

  .K(K),
  .Beta(1),
  .BA(1),
  .segA(segA),
  .segB(segB),
  .Bs(Bs),

  .R(melody),
  .H(H),
  .S(S)

);

///////////// SDRAM /////////////

reg [24:0] sdram_addr;
wire [7:0] sdram_data;
reg sdram_rd, sdram_wr;
wire sdram_rdy;

// SDRAM addr mux
always @(posedge clk_sys) begin
  sdram_rd <= 1'b0;
  sdram_wr <= 1'b0;
  if (ioctl_download) begin
    sdram_addr <= ioctl_addr;
    sdram_wr <= ioctl_wr;
  end
  else if (rom_img_read) begin
    sdram_addr <= rom_base_image_addr + rom_img_addr;
    sdram_rd <= 1'b1;
  end
end

sdram sdram
(
  .*,
  .init(~locked),
  .clk(clk_sys),
  .addr(sdram_addr),
  .wtbt(0),
  .dout(sdram_data),
  .din(ioctl_dout),
  .rd(sdram_rd),
  .we(sdram_wr),
  .ready(sdram_rdy)
);

/////////// DDRAM ////////////////////

assign DDRAM_CLK = clk_sys;
assign FB_EN = 1'b1;
assign FB_BASE = 'h30000000;
assign FB_WIDTH = 12'd720;
assign FB_HEIGHT = 12'd480;
assign FB_FORMAT = 5'b0_0_011;
assign FB_STRIDE = 14'd720;
assign FB_FORCE_BLANK = 0;

wire [28:0] fb_addr;
wire [63:0] fb_data;
wire fb_req, fb_ready;


ddram ddram(
  .*,
  .ch1_addr(fb_addr),
  .ch1_dout(),
  .ch1_din(fb_data),
  .ch1_req(fb_req),
  .ch1_rnw(1'b0),
  .ch1_ready(fb_ready)
);


endmodule
