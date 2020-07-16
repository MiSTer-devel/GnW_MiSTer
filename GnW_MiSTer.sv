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
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] VIDEO_ARX,
	output  [7:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,

	/*
	// Use framebuffer from DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of 16 bytes.

	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	*/

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
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;

assign VGA_SL = 0;
assign VGA_F1 = 0;

assign AUDIO_S = 0;
assign AUDIO_L = { melody[0], 15'd0 };
assign AUDIO_R = { melody[0], 15'd0 };
assign AUDIO_MIX = 2'd3;

assign LED_DISK = ioctl_download;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

`include "build_id.v"
localparam CONF_STR = {
	"Game & Watch;;",
	"-;",
	"F,BIN,Load File;",
	"-;",
	"O1,Aspect Ratio,Original,4/3;",
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
wire [15:0] joystick_0;
wire [15:0] joystick_1;

wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        ioctl_download;
wire  [7:0] ioctl_index;
wire		ioctl_wait;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(),

	.conf_str(CONF_STR),
	.forced_scandoubler(forced_scandoubler),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1),

	.buttons(buttons),
	.status(status),
	.status_menumask({status[5]}),

	.ps2_key(ps2_key),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wait(ioctl_wait),
	.ioctl_index(ioctl_index)
);


///////////////////////   CLOCKS   ///////////////////////////////

wire locked;
wire clk_sys;
wire clk_vid;
wire clk_lcd;
reg [2:0] clk_div;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys), // 100
	.outclk_1(clk_vid), // 25
	.locked(locked)
);

always @(posedge clk_sys)
  clk_div <= clk_div + 3'd1;

assign clk_lcd = clk_div[2];

wire reset = RESET | status[0] | buttons[1] | ioctl_download;

//////////////////////////////////////////////////////////////////

wire [15:0] segA;
wire [15:0] segB;
wire Bs;

wire [1:0] melody;
wire [3:0] H;
wire [7:0] S;

reg mcuid;
reg [7:0] joy_config[11:0];
always @(posedge clk_sys)
    if (ioctl_download) begin
        if (ioctl_addr == 0) mcuid <= ioctl_dout;
        if (ioctl_addr >= 1 && ioctl_addr <= 12) joy_config[ioctl_addr-1] <= ioctl_dout;
	end

wire [31:0] joy = joystick_0;

wire [3:0] K;
always @*
  case (S[2:0])
    3'b001: K = { joy[joy_config[ 1][3:0]], joy[joy_config[ 1][7:4]], joy[joy_config[ 0][3:0]], joy[joy_config[ 0][7:4]]};
    3'b010: K = { joy[joy_config[ 3][3:0]], joy[joy_config[ 3][7:4]], joy[joy_config[ 2][3:0]], joy[joy_config[ 2][7:4]]};
    3'b100: K = { joy[joy_config[ 5][3:0]], joy[joy_config[ 5][7:4]], joy[joy_config[ 4][3:0]], joy[joy_config[ 4][7:4]]};
//    6'b001000: K = { joy[joy_config[ 7][3:0]], joy[joy_config[ 7][7:4]], joy[joy_config[ 6][3:0]], joy[joy_config[ 6][7:4]]};
//    6'b010000: K = { joy[joy_config[ 9][3:0]], joy[joy_config[ 9][7:4]], joy[joy_config[ 8][3:0]], joy[joy_config[ 8][7:4]]};
//    6'b100000: K = { joy[joy_config[11][3:0]], joy[joy_config[11][7:4]], joy[joy_config[10][3:0]], joy[joy_config[10][7:4]]};
  endcase

localparam SCREENSIZE = 640*480;

wire rom_init = ioctl_download && ioctl_addr >= 2*SCREENSIZE+13;
wire [11:0] rom_init_addr = ioctl_addr - 2*SCREENSIZE-13;

SM510 mcu(
  .rst(reset),
  .clk(clk_sys),

  .rom_init(rom_init),
  .rom_init_data(ioctl_dout),
  .rom_init_addr(rom_init_addr),

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


wire [24:0] sdram_addr;
wire [7:0] sdram_data;
wire sdram_rd;

wire [7:0] lcd_dout;
wire [7:0] video_data;
wire [18:0] video_addr;
wire [18:0] lcd_addr;
wire vram_we;

wire hsync;
wire vsync;
wire hblank;
wire vblank;
assign CLK_VIDEO = clk_vid;
assign VIDEO_ARX = status[1] ? 8'd4 : 8'd16;
assign VIDEO_ARY = status[1] ? 8'd3: 8'd9;
wire [7:0] red, green, blue;


vram vram(
  .clk(clk_sys),
  .addr_wr(lcd_addr),
  .din(lcd_dout),
  .we(vram_we),

  .addr_rd(video_addr),
  .dout(video_data)
);


lcd lcd(
  .clk(clk_lcd),
  .lcd_addr(lcd_addr),
  .lcd_dout(lcd_dout),
  .lcd_vram_we(vram_we),

  .sdram_addr(sdram_addr),
  .sdram_data(sdram_data),
  .sdram_rd(sdram_rd),

  .segA(segA),
  .segB(segB),
  .Bs(Bs),
  .H(H),

  .rdy(~ioctl_download)
);


video video(
  .clk_vid(clk_vid),
  .ce_pxl(CE_PIXEL),
  .hsync(hsync),
  .vsync(vsync),
  .hblank(hblank),
  .vblank(vblank),
  .red(red),
  .green(green),
  .blue(blue),
  .addr(video_addr),
  .din(video_data)
);


video_cleaner video_cleaner(
	.clk_vid(clk_vid),
	.ce_pix(CE_PIXEL),
	.R(red),
	.G(green),
	.B(blue),
	.HSync(~hsync),
	.VSync(~vsync),
	.HBlank(hblank),
	.VBlank(vblank),
	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B),
	.VGA_VS(VGA_VS),
	.VGA_HS(VGA_HS),
	.VGA_DE(VGA_DE)
);

// offset by 13 when reading because of config bytes
wire [24:0] shift_sdram_addr = sdram_addr + 25'd13;
sdram sdram
(
	.*, // <= it's bad practice, todo: fix
	.init(~locked),
	.clk(clk_sys),
	.addr(ioctl_download ? ioctl_addr : shift_sdram_addr),
	.wtbt(0),
	.dout(sdram_data),
	.din(ioctl_dout),
	.rd(sdram_rd),
	.we(ioctl_wr),
	.ready()
);


endmodule
