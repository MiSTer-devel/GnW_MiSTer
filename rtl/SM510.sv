
/* verilator lint_off CASEINCOMPLETE */

module SM510(
  input rst,
  input clk,

  input rom_init,
  input [7:0] rom_init_data,
  input [11:0] rom_init_addr,

  input [23:0] hms, // HHMMSS in 24h format
  input [6:0] hms_loc, // storage location

  input [3:0] K, // key input ports

  input Beta,
  input BA,

  output reg [15:0] segA,
  output reg [15:0] segB,
  output reg Bs,

  output reg [1:0] R, // melody output ports
  output reg [3:0] H, // common output ports
  output [7:0] S      // strobe output ports

);

parameter MAIN_CLK = 90000000;
parameter CLK_DIV1 = MAIN_CLK/16384; // timer
parameter CLK_DIV2 = MAIN_CLK/32768; // CPU
parameter CLK_DIV3 = MAIN_CLK/8192; // sound
parameter CLK_DIV4 = MAIN_CLK/64; // segments


reg [1:0] Pu, Su, Ru;
reg [3:0] Pm, Sm, Rm;
reg [5:0] Pl, Sl, Rl;
reg [3:0] A, Y, L;
reg [2:0] Bm;
reg [3:0] Bl;
reg [7:0] W;
reg [23:0] clk_cnt1, clk_cnt2;
reg [23:0] clk_cnt3, clk_cnt4;
reg [7:0] rom[4095:0];
reg [3:0] ram[127:0];
reg [7:0] rom_dout;
reg [3:0] ram_dout;
reg [6:0] ram_addr;
wire [7:0] op = rom_dout;
reg [7:0] prev_op;
reg [2:0] state;
reg [3:0] alu_b, alu_r;
reg [1:0] alu_op;
reg sbm;
reg [14:0] div;
reg [3:0] BP;
reg [1:0] RP;
reg BC;
reg Gamma; // 1s f/f
reg tis_read; // 1s read flag
reg alu_cy;
reg C;
reg [1:0] H_clk;
reg halt;
reg buzzer;

wire f1 = div[14];
wire f4 = div[10];

wire [11:0] PC = { Pu, Pm, Pl };
assign S = W;

reg clk_16k;
reg clk_32k;
reg clk_4k;
reg clk_64;

always @(posedge clk) begin
  clk_cnt1 <= clk_cnt1 + 24'd1;
  clk_16k <= 1'b0;
  if (clk_cnt1 == CLK_DIV1) begin
    clk_16k <= 1'b1;
    clk_cnt1 <= 0;
  end
end


always @(posedge clk) begin
  clk_cnt2 <= clk_cnt2 + 24'd1;
  clk_32k <= 1'b0;
  if (clk_cnt2 == CLK_DIV2) begin
    clk_32k <= 1'b1;
    clk_cnt2 <= 0;
  end
end

always @(posedge clk) begin
  clk_cnt3 <= clk_cnt3 + 24'd1;
  clk_4k <= 1'b0;
  if (clk_cnt3 == CLK_DIV3) begin
    clk_4k <= 1'b1;
    clk_cnt3 <= 0;
  end
end

always @(posedge clk) begin
  clk_cnt4 <= clk_cnt4 + 24'd1;
  clk_64 <= 1'b0;
  if (clk_cnt4 == CLK_DIV4) begin
    clk_64 <= 1'b1;
    clk_cnt4 <= 0;
  end
end

parameter
  RST = 3'b000,
  FT1 = 3'b001,
  FT2 = 3'b010,
  FT3 = 3'b011,
  SKP = 3'b100,
  SK2 = 3'b101,
  FT4 = 3'b110;


always @(posedge clk)
  if (rom_init) rom[rom_init_addr] <= rom_init_data;

// Gamma
always @(posedge clk) begin
  if (clk_16k) begin
    if (div == 15'h3fff) Gamma <= 1'b1;
  end
  if (rst | tis_read) Gamma <= 1'b0;
end

// div
always @(posedge clk) begin
  if (clk_16k) begin
    if (op == 8'b0110_0101 && state == FT1) // idiv
      div <= 15'd0;
    else if (op == 8'b0101_1101 && state == FT1) // cend
      div <= 15'd0;
    else
      div <= div + 15'd1;
  end
  if (rst) div <= 15'd0;
end

// halt
always @(posedge clk) begin
  if (clk_32k) begin
    if (op == 8'b0101_1101 && state == FT1) // CEND
      halt <= 1'b1;
    else if (f1 || K)
      halt <= 1'b0;
  end
end

// lcd driver
// video ram $60-7F
parameter disp_ram = 7'h60;
reg [31:0] seg_cache[3:0];
reg [4:0] seg_cache_addr;
reg [3:0] seg_cache_data;
reg read;
always @(posedge clk) begin
  read <= ~read;
  if (read) begin
    seg_cache_data <= ram[disp_ram+seg_cache_addr];
  end
  else begin
    seg_cache[0][seg_cache_addr] <= seg_cache_data[0];
    seg_cache[1][seg_cache_addr] <= seg_cache_data[1];
    seg_cache[2][seg_cache_addr] <= seg_cache_data[2];
    seg_cache[3][seg_cache_addr] <= seg_cache_data[3];
    seg_cache_addr <= seg_cache_addr + 5'd1;
  end
end

always @(posedge clk) begin
  if (clk_64) begin
    H_clk <= H_clk + 2'b1;
    H <= 1'b1 << H_clk;
    segA <= seg_cache[H_clk][15:0];
    segB <= seg_cache[H_clk][31:16];
  end
end

// Bs
always @(posedge clk) begin
  if (clk_64) begin
    if (BP & ~BC) Bs <= 1'((L & ~Y) >> H_clk);
  end
end

// rom
always @(posedge clk)
  rom_dout <= rom[PC];

// BCD rom
reg [7:0] bcd_vector;
reg [7:0] hexval;
always @*
  case (hexval)
    8'h00, 8'h01, 8'h02, 8'h03, 8'h04,
    8'h05, 8'h06, 8'h07, 8'h08, 8'h09:
      bcd_vector <= 8'h0;
    8'h0a, 8'h0b, 8'h0c, 8'h0d, 8'h0e, 8'h0f:
      bcd_vector <= 8'h16;
    8'h10, 8'h11, 8'h12, 8'h13:
      bcd_vector <= 8'h06;
    8'h14, 8'h15, 8'h16, 8'h17, 8'h18,
    8'h19, 8'h1a, 8'h1b, 8'h1c, 8'h1d:
      bcd_vector <= 8'h1c;
    8'h1e, 8'h1f:
      bcd_vector <= 8'h22;
    8'h20, 8'h21, 8'h22, 8'h23, 8'h24,
    8'h25, 8'h26, 8'h27:
      bcd_vector <= 8'h12;
    8'h28, 8'h29, 8'h2a, 8'h2b, 8'h2c,
    8'h2d, 8'h2e, 8'h2f:
      bcd_vector <= 8'h28;
    8'h30, 8'h31:
      bcd_vector <= 8'h18;
    8'h32, 8'h33, 8'h34, 8'h35, 8'h36,
    8'h37, 8'h38, 8'h39, 8'h3a, 8'h3b:
      bcd_vector <= 8'h2e;
  endcase

// ram
reg [23:0] oldhms;
reg set_time;
reg [2:0] hms_addr;
reg old_rst;
always @(posedge clk) begin
  old_rst <= rst;
  if (!set_time) oldhms <= hms;
  if (hms^oldhms && |hms) begin
    set_time <= 1'b1;
    hms_addr <= 3'd0;
    $display("setting time");
  end
  if (~rst & old_rst) set_time <= 1'b1;
  if (set_time) begin
    case (hms_addr)
      3'd0: begin // AM/PM + H upper digit
        if (Gamma) begin // wait 1s
          ram[hms_loc+hms_addr] <= {
            hms[23:16] > 8'd12 ? 1'b1 : 1'b0,
            hms[23:16] > 8'd21 ? 3'd1 :
            hms[23:16] > 8'd12 ? 3'd0 :
            hms[23:16] > 8'd9 ? 3'd1 : 3'd0
          };
          // 24h -> 12h conversion
          hexval <= hms[23:16] > 8'd12 ? 4'(hms[23:16] + 4'd4) : hms[23:16];
          hms_addr <= hms_addr + 3'd1;
        end
      end
      3'd1: begin // H lower digit
        ram[hms_loc+hms_addr] <= hexval[3:0] + bcd_vector[3:0];
        hexval <= hms[15:8];
        hms_addr <= hms_addr + 3'd1;
      end
      3'd2: begin // M upper digit
        ram[hms_loc+hms_addr] <= hms[15:12] + bcd_vector[7:4];
        hms_addr <= hms_addr + 3'd1;
      end
      3'd3: begin // M lower digit
        ram[hms_loc+hms_addr] <= hms[11:8] + bcd_vector[3:0];
        hexval <= hms[7:0];
        hms_addr <= hms_addr + 3'd1;
      end
      3'd4: begin // S upper digit
        ram[hms_loc+hms_addr] <= hms[7:4] + bcd_vector[7:4];
        hms_addr <= hms_addr + 3'd1;
      end
      3'd5: begin // S lower digit
        ram[hms_loc+hms_addr] <= hms[3:0] + bcd_vector[3:0];
        set_time <= 1'b0;
        hms_addr <= 3'd0;
      end
    endcase
  end
  if (clk_32k) begin
    if (state == FT2)
      casez (op)
        8'b0000_?1??: ram[ram_addr] <= op[3] ? ram_dout | (1 << op[1:0]) : ram_dout & ~(1 << op[1:0]); // rm sm
        8'b0001_0???,
        8'b0001_11??: ram[ram_addr] <= A;
      endcase
  end
  ram_dout <= ram[ram_addr];
end

// ram_addr
always @(posedge clk) begin
  ram_addr = { Bm, Bl };
  if (sbm) ram_addr = { 1'b1, Bm[1:0], Bl };
end

// sbm
always @(posedge clk)
  if (prev_op == 8'b0000_0010 && state != SKP)
    sbm = 1'b1;
  else
    sbm = 1'b0;

// alu
always @(posedge clk)
  if (state == FT2)
    case (alu_op)
      2'b00: { alu_cy, alu_r } <= A + alu_b;
      2'b10: { alu_cy, alu_r } <= A + alu_b + C;
      2'b11: { alu_r, alu_cy } <= { C, A };
    endcase

// alu b
always @(posedge clk)
  if (state == FT1)
    casez (op)
      8'b0000_100?: // ADD ADD11
        alu_b <= ram_dout;
      8'b0011_????: // ADX
        alu_b <= op[3:0];
    endcase

// alu op
always @(posedge clk)
  if (state == FT1)
    casez (op)
      8'b0011_????, // ADX
      8'b0000_1000: // ADD
        alu_op <= 2'b0;
      8'b0000_1001: // ADD11
        alu_op <= 2'b10;
      8'b0110_1011: // ROT
        alu_op <= 2'b11;
    endcase

// C
always @(posedge clk)
  if (clk_32k) begin
    if (state == FT2) begin
      casez (op)
        8'b0110_011?: // RC SC
          C <= op[0];
        8'b0110_1011, // ROT
        8'b0000_1001: // ADD11
          C <= alu_cy;
      endcase
    end
  end

// previous op
always @(posedge clk)
  if (clk_32k) begin
    if (state == FT2) prev_op <= op;
  end

// W shift register
always @(posedge clk)
  if (clk_32k && state == FT2)
    if (op[7:1] == 7'b0110_001) // WR WS
      W <= { W[6:0], op[0] };

// I/O: BP L Y R'
always @(posedge clk)
  if (clk_32k && state == FT2) begin
    case (op)
      8'b0000_0001: BP <= A; // ATBP
      8'b0101_1001: L <= A; // ATL
      8'b0110_0000: Y <= A; // ATFC
      8'b0110_0001: RP <= A[1:0]; // ATR
      default: begin
        BP <= 4'b1;
      end
    endcase
  end


// R
// R0/R1 have inverted phase
always @(posedge clk) begin
  if (clk_4k) begin
    buzzer <= ~buzzer;
    R[0] <= RP[0] ? buzzer : 1'b0;
    R[1] <= RP[1] ? ~buzzer : 1'b0;
  end
end

// BC (crystal bleeder current, active low)
always @(posedge clk)
  if (op == 8'b0110_1101)
    BC <= C;

// PC & stack (PC => S => R)
always @(posedge clk)
  if (rst)
    { Pu, Pm, Pl } <= { 2'd3, 4'd7, 6'd0 };
  else if (halt)
    { Pu, Pm, Pl } <= { 2'd1, 4'd0, 6'd0 };
  else if (clk_32k) begin
    case (state)
      SKP:
        Pl <= { Pl[1] == Pl[0], Pl[5:1] };
      FT2:
        casez (op)
          8'b0000_0011: // ATPL
            Pl[3:0] <= A;
          8'b0110_111?: begin // RTN0 RTN1
            { Pu, Pm, Pl } <= { Su, Sm, Sl };
            { Su, Sm, Sl } <= { Ru, Rm, Rl };
          end
          8'b10??_????: // T
            Pl <= op[5:0];
          8'b11??_????: begin // TM
            { Ru, Rm, Rl } <= { Su, Sm, Sl };
            { Su, Sm, Sl } <= { Pu, Pm, { Pl[1] == Pl[0], Pl[5:1] } };
          end
          default:
            Pl <= { Pl[1] == Pl[0], Pl[5:1] };
        endcase
      FT3:
        casez (prev_op)
          8'b0111_????: begin // TL
            Pu <= rom_dout[7:6];
            Pm <= prev_op[3:0];
            Pl <= rom_dout[5:0];
            if (prev_op[3:2] == 2'b11) begin // TML
              { Ru, Rm, Rl } <= { Su, Sm, Sl };
              { Su, Sm, Sl } <= { Pu, Pm, { Pl[1] == Pl[0], Pl[5:1] } };
              Pm <= { 2'b0, prev_op[1:0] };
            end
          end
          8'b11??_????: // TM
            { Pu, Pl, Pm } <= { rom[12'(op[5:0])], 4'b0100 };
          default:
            Pl <= { Pl[1] == Pl[0], Pl[5:1] };
        endcase
    endcase
  end

// Acc
always @(posedge clk)
  if (clk_32k) begin
    if (state == FT1) begin
      if (op[7:4] == 4'b0010 && op[7:4] != prev_op[7:4]) A <= op[3:0]; // LAX
    end
    else if (state == FT2) begin
      casez (op)
        8'b0000_1011: // EXBLA
          A <= Bl;
        8'b0001_????: // LDA EXC*
          A <= ram_dout;
        8'b0110_1010: // KTA
          A <= K;
        8'b0000_100?, // ADD ADD11
        8'b0110_1011, // ROT
        8'b0011_????: // ADX
          A <= alu_r;
        8'b0000_1010: // COMA
          A <= ~A;// ^ 4'hf;
      endcase
    end
  end

// Bl
always @(posedge clk)
  if (clk_32k) begin
    case (state)
      FT2:
        casez (op)
          8'b0100_????: begin // LB
            Bl <= {  op[3]|op[2], op[3]|op[2], op[3:2] };
          end
          8'b0000_1011: // EXBLA
            Bl <= A;
          8'b0001_01??,
          8'b0110_0100: Bl <= Bl + 1; // incb
          8'b0001_11??,
          8'b0110_1100: Bl <= Bl - 1; // decb
        endcase
      FT3:
        casez (prev_op)
          8'b0101_1111: // LBL
            Bl <= rom_dout[3:0];
        endcase
    endcase
  end

// Bm
always @(posedge clk)
  if (clk_32k) begin
    case (state)
      FT2: begin
        casez (op)
          8'b0100_????: // LB
            Bm[1:0] <= op[1:0];
          8'b0001_????: // LDA EXC*
            Bm[1:0] <= Bm[1:0] ^ op[1:0];
        endcase
      end
      FT3:
        casez (prev_op)
          8'b0101_1111: // LBL
            Bm <= rom_dout[6:4];
        endcase
    endcase
  end

// tis_read
always @(posedge clk)
  if (clk_32k) begin
    if (state == FT2) begin
      if (~Gamma) tis_read <= 1'b0;
      else if (op == 8'b0101_1000) tis_read <= 1'b1; // TIS
    end
  end

// fsm
always @(posedge clk) begin
  if (rst) state <= FT1;
  if (clk_32k) begin
    if (~rst && ~halt) begin
      state <= FT1;
      if (state == FT1) state <= FT2;
      else if (state == SKP) state <= SK2;
      else if (state == FT3) state <= FT4;
      else if (state == FT2) begin
        casez (op)
          8'b0101_1000: // TIS
            state <= Gamma ? FT1 : SKP;
          8'b0101_1111, // LBL
          8'b0111_????: // TL TML
            state <= FT3;
          8'b0110_1111: // RTN1
            state <= SKP;
          8'b0101_0010: // TC
            state <= ~C ? SKP : FT1;
          8'b0011_????: // ADX
            state <= alu_cy && op[3:0] != 4'hA ? SKP : FT1; // DC=0x3A
          8'b0000_1001: // ADD11
            state <= alu_cy ? SKP : FT1;
          8'b0001_01??, // exci
          8'b0110_0100: state <= Bl == 4'hf ? SKP : FT1; // incb
          8'b0001_11??, // excd
          8'b0110_1100: state <= Bl == 4'h0 ? SKP : FT1; // decb
          8'b0101_0001: // TB
            state <= Beta == 1'b1 ? SKP : FT1;
          8'b0101_0011: // TAM
            state <= A == ram_dout ? SKP : FT1;
          8'b0101_01??: // TMI
            state <= ram_dout[op[1:0]] ? SKP : FT1;
          8'b0101_1010: // TA0
            state <= A == 0 ? SKP : FT1;
          8'b0101_1011: // TABL
            state <= A == Bl ? SKP : FT1;
          8'b0101_1110: // TAL
            state <= BA ? SKP : FT1;
          8'b0110_1000: // TF1
            state <= f1 ? SKP : FT1;
          8'b0110_1001: // TF4
            state <= f4 ? SKP : FT1;
          8'b11??_????: // TM
            state <= FT3;
        endcase
      end
    end
  end
end


endmodule
