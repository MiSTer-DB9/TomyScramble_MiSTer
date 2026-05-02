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
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,
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
	output	USER_OSD,
	// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: per-pin push-pull mask
	output	[7:0] USER_PP,
	// [MiSTer-DB9 END]
input	[7:0] USER_IN,
output	[7:0] USER_OUT,

	input         OSD_STATUS
);


// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: USER_PP default (port_batch replaces with USER_PP_DRIVE)
assign USER_PP = USER_PP_DRIVE;
// [MiSTer-DB9 END]
///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joydb wrapper
wire         CLK_JOY = CLK_50M;                 // Assign clock between 40-50Mhz
wire   [1:0] joy_type        = status[127:126]; // 0=Off, 1=Saturn, 2=DB9MD, 3=DB15
wire         joy_2p          = status[125];
wire         joy_db9md_en    = (joy_type == 2'd2);
wire         joy_db15_en     = (joy_type == 2'd3);
wire         joy_any_en      = |joy_type;
// Legacy 3-bit alias for fork-specific MT32 / SNAC fallback code. Non-canonical
// RHS variants (ext_iec_en, mt32_disable) need a hand-port — alias is raw.
wire   [2:0] JOY_FLAG        = {joy_db9md_en, joy_db15_en, joy_2p};
// [MiSTer-DB9 END]

// [MiSTer-DB9-Pro BEGIN] - Saturn key gate
wire         saturn_unlocked;                   // driven by hps_io UIO_DB9_KEY (0xFE)
// [MiSTer-DB9-Pro END]

// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joydb wrapper wires + instance
wire   [7:0] USER_OUT_DRIVE;
wire   [7:0] USER_PP_DRIVE;
wire  [15:0] joydb_1, joydb_2;
wire         joydb_1ena, joydb_2ena;
wire  [15:0] joy_raw_payload;

joydb joydb (
  .clk             ( CLK_JOY         ),
  .USER_IN         ( USER_IN         ),
  .joy_type        ( joy_type        ),
  .joy_2p          ( joy_2p          ),
  .saturn_unlocked ( saturn_unlocked ),
  .USER_OUT_DRIVE  ( USER_OUT_DRIVE  ),
  .USER_PP_DRIVE   ( USER_PP_DRIVE   ),
  .USER_OSD        ( USER_OSD        ),
  .joydb_1         ( joydb_1         ),
  .joydb_2         ( joydb_2         ),
  .joydb_1ena      ( joydb_1ena      ),
  .joydb_2ena      ( joydb_2ena      ),
  .joy_raw         ( joy_raw_payload )
);

assign USER_OUT = USER_OUT_DRIVE;
// [MiSTer-DB9 END]

assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;

assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

assign AUDIO_S = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign LED_USER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

assign VIDEO_ARX = status[1] ? 8'd4 : 8'd16;
assign VIDEO_ARY = status[1] ? 8'd3 : 8'd9;

`include "build_id.v"
localparam CONF_STR = {
	"TomyScramble;;",
	"-;",
	"O1,Aspect ratio,original,4:3;",
	"O2,Mode,Ama,Pro;",
	"-;",
	"F,rom,Load File;", // remove
	"-;",
		// [MiSTer-DB9-Pro BEGIN] - Saturn-first joy_type (canonical bit notation)
	"O[127:126],UserIO Joystick,Off,Saturn,DB9MD,DB15;",
	"O[125],UserIO Players, 1 Player,2 Players;",
	// [MiSTer-DB9-Pro END]
	"-;",
	"T0,Reset;",
	"R0,Reset and close OSD;",
	"V,v",`BUILD_DATE
};

wire forced_scandoubler;
wire  [1:0] buttons;
wire [15:0] joystick_0_USB;
// [MiSTer-DB9 BEGIN] - widened to 128 bits for joy_type at [127:126] and joy_2p at [125]
wire [127:0] status;
// [MiSTer-DB9 END]
wire [10:0] ps2_key;

wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_index;
wire ioctl_wr;
wire ioctl_download;
wire ioctl_wait;

// M S F2 F1 U D L R 
wire [31:0] joystick_0 = joydb_1ena ? (OSD_STATUS? 32'b000000 : {joydb_1[11],joydb_1[10],joydb_1[5:0]}) : joystick_0_USB;






hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(),

	.forced_scandoubler(forced_scandoubler),

	.joystick_0(joystick_0_USB),
	.buttons(buttons),
	.status(status),
	.status_menumask({status[5]}),

	// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joy_raw
	.joy_raw(OSD_STATUS ? joy_raw_payload : 16'b0),
	// [MiSTer-DB9 END]
	// [MiSTer-DB9-Pro BEGIN] - Saturn key gate
	.saturn_unlocked(saturn_unlocked),
	// [MiSTer-DB9-Pro END]
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
wire clk_vfd = clk_div[2];
reg  clk_mcu;

reg [2:0] clk_div;
reg [23:0] clk_cnt;

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

always @(posedge clk_sys)
	{ clk_mcu, clk_cnt } <= clk_cnt + 24'd67108;

wire reset = RESET | status[0] | buttons[1] | ioctl_download;

//////////////////////////////////////////////////////////////////

wire [24:0] sdram_addr;
wire [7:0] sdram_data;
wire sdram_rd;

wire [7:0] vfd_dout;
wire [7:0] video_data;
wire [18:0] video_addr;
wire [18:0] vfd_addr;
wire vram_we;

wire hsync;
wire vsync;
wire hblank;
wire vblank;
assign CLK_VIDEO = clk_vid;
wire [7:0] red, green, blue;
wire pro = status[2];

wire [3:0] prtAI = { joystick_0[4], joystick_0[4], joystick_0[4], pro };
wire [3:0] prtBI = { 2'b11, joystick_0[2], joystick_0[3] };
wire [3:0] prtCI;
wire [3:0] prtDI;
wire [3:0] prtC;
wire [3:0] prtD;
wire [3:0] prtE;
wire [3:0] prtF;
wire [3:0] prtG;
wire [3:0] prtH;
wire [2:0] prtI;

wire rom_init = ioctl_download & (ioctl_addr >= 2*640*480);
wire [11:0] rom_init_addr = ioctl_addr - 2*640*480;

assign AUDIO_L = { prtI[2], 15'd0 };
assign AUDIO_R = { prtI[2], 15'd0 };
assign AUDIO_MIX = 2'd3;

ucom43 ucom43(
	.clk(clk_mcu),
	.reset(reset),
	._INT(0),
	.prtAI(prtAI),
	.prtBI(prtBI),
	.prtCI(prtCI),
	.prtDI(prtDI),
	.prtC(prtC),
	.prtD(prtD),
	.prtE(prtE),
	.prtF(prtF),
	.prtG(prtG),
	.prtH(prtH),
	.prtI(prtI),
	// rom injection
	.clk_sys(clk_sys),
	.rom_init(rom_init),
	.rom_init_data(ioctl_dout),
	.rom_init_addr(rom_init_addr)
);

vram vram(
	.clk(clk_sys),
	.addr_wr(vfd_addr),
	.din(vfd_dout),
	.we(vram_we),
	.addr_rd(video_addr),
	.dout(video_data)
);

vfd vfd(
	.clk(clk_vfd),
	.vfd_addr(vfd_addr),
	.vfd_dout(vfd_dout),
	.vfd_vram_we(vram_we),

	.sdram_addr(sdram_addr),
	.sdram_data(sdram_data),
	.sdram_rd(sdram_rd),

	.C(prtC),
	.D(prtD),
	.E(prtE),
	.F(prtF),
	.G(prtG),
	.H(prtH),
	.I(prtI),

	.rdy(~reset)
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

sdram sdram
(
	.*,
	.init(~locked),
	.clk(clk_sys),
	.addr(ioctl_download ? ioctl_addr : sdram_addr),
	.wtbt(0),
	.dout(sdram_data),
	.din(ioctl_dout),
	.rd(sdram_rd),
	.we(ioctl_wr),
	.ready()
);


endmodule
