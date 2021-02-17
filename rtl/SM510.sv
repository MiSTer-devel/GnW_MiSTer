
/* verilator lint_off CASEINCOMPLETE */

module SM510(
  input rst,
  input clk,

  input rom_init,
  input [7:0] rom_init_data,
  input [11:0] rom_init_addr,

  input [3:0] K, // key input ports

  input Beta,
  input BA,

  output [15:0] segA,
  output [15:0] segB,
  output reg Bs,

  output reg [1:0] R, // melody output ports
  output reg [3:0] H, // common output ports
  output [7:0] S, // strobe output ports

  output dbg

);

reg [1:0] Pu, Su, Ru;
reg [3:0] Pm, Sm, Rm;
reg [5:0] Pl, Sl, Rl;
reg [3:0] A, Y, L;
reg [2:0] Bm;
reg [3:0] Bl;
reg [7:0] W;
reg [23:0] clk_cnt;
reg [7:0] rom[4095:0];
reg [3:0] ram[127:0];
reg [7:0] rom_dout;
reg [3:0] ram_dout;
reg [3:0] ram_din;
reg [6:0] ram_addr;
reg [4:0] bit_mask; // { s=1/r=0, mask }
reg [7:0] op;
reg [7:0] prev_op;
reg [2:0] state;
reg [3:0] alu_a, alu_b, alu_r;
reg [1:0] alu_op;
reg sbm;
reg [14:0] div;
reg [3:0] BP;
reg [1:0] RP;
reg BC;
reg Gamma; // 1s f/f
reg tis_read; // 1s read flag
reg ram_we;
reg alu_cy;
reg C;
reg [1:0] H_clk;
reg halt;

wire f1 = div[14];
wire f4 = div[11];

wire [11:0] PC = { Pu, Pm, Pl };
assign S = W;

reg clk_32k;
// reg clk_v;

// 100M/0.032768=3051, 2^24/3051=5498
// 48/0.032768=1464, 2^24/1464=11459
// always @(posedge clk)
// 	{ clk_v, clk_cnt } <= clk_cnt + 24'd11459;
always @(posedge clk) begin
	clk_cnt <= clk_cnt + 24'd1;
	clk_32k <= 1'b0;
	if (clk_cnt == 24'd3714) begin
	  clk_32k <= 1'b1;
	  clk_cnt <= 0;
	end
end

// always @(posedge clk)
//   if (clk_v) clk_32k = ~clk_32k;

wire clk_64 = div[6]; // TODO: try to increase segment speed (div[4]?)
wire clk_io = div[1];

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
  if (f1) Gamma <= 1'b1;
  else if (rst | tis_read) Gamma <= 1'b0;
end

assign dbg = Gamma;

// div
always @(posedge clk_32k)
  if (f1 || rst || (op == 8'b0110_0101 && state == FT1))
    div <= 15'b0;
  else
    div <= div + 15'd1;


// halt
always @(posedge clk_32k)
  if (op == 8'b0101_1101 && state == FT1) // CEND
    halt <= 1'b1;
  else if (f1 || K)
    halt <= 1'b0;

// lcd driver
parameter disp_ram = 7'h60;
always @(posedge clk_64) begin

  if (BP & ~BC) begin

    H_clk <= H_clk + 2'b1;
    H <= 1'b1 << H_clk;

    segA[4'd00] <= ram[disp_ram+7'h00][H_clk];
    segA[4'd01] <= ram[disp_ram+7'h01][H_clk];
    segA[4'd02] <= ram[disp_ram+7'h02][H_clk];
    segA[4'd03] <= ram[disp_ram+7'h03][H_clk];
    segA[4'd04] <= ram[disp_ram+7'h04][H_clk];
    segA[4'd05] <= ram[disp_ram+7'h05][H_clk];
    segA[4'd06] <= ram[disp_ram+7'h06][H_clk];
    segA[4'd07] <= ram[disp_ram+7'h07][H_clk];
    segA[4'd08] <= ram[disp_ram+7'h08][H_clk];
    segA[4'd09] <= ram[disp_ram+7'h09][H_clk];
    segA[4'd10] <= ram[disp_ram+7'h0a][H_clk];
    segA[4'd11] <= ram[disp_ram+7'h0b][H_clk];
    segA[4'd12] <= ram[disp_ram+7'h0c][H_clk];
    segA[4'd13] <= ram[disp_ram+7'h0d][H_clk];
    segA[4'd14] <= ram[disp_ram+7'h0e][H_clk];
    segA[4'd15] <= ram[disp_ram+7'h0f][H_clk];

    segB[4'd00] <= ram[disp_ram+7'h10][H_clk];
    segB[4'd01] <= ram[disp_ram+7'h11][H_clk];
    segB[4'd02] <= ram[disp_ram+7'h12][H_clk];
    segB[4'd03] <= ram[disp_ram+7'h13][H_clk];
    segB[4'd04] <= ram[disp_ram+7'h14][H_clk];
    segB[4'd05] <= ram[disp_ram+7'h15][H_clk];
    segB[4'd06] <= ram[disp_ram+7'h16][H_clk];
    segB[4'd07] <= ram[disp_ram+7'h17][H_clk];
    segB[4'd08] <= ram[disp_ram+7'h18][H_clk];
    segB[4'd09] <= ram[disp_ram+7'h19][H_clk];
    segB[4'd10] <= ram[disp_ram+7'h1a][H_clk];
    segB[4'd11] <= ram[disp_ram+7'h1b][H_clk];
    segB[4'd12] <= ram[disp_ram+7'h1c][H_clk];
    segB[4'd13] <= ram[disp_ram+7'h1d][H_clk];
    segB[4'd14] <= ram[disp_ram+7'h1e][H_clk];
    segB[4'd15] <= ram[disp_ram+7'h1f][H_clk];
  end

end

// Bs
always @(posedge clk_64)
  if (BP & ~BC)
    Bs <= 1'((L & ~Y) >> H_clk);

// rom
// todo: clock rom_addr <= PC
always @(posedge clk)
  rom_dout <= rom[PC];

// ram
always @(posedge clk_32k) begin
  if (~ram_we)
    ram[ram_addr] <= ram_din;
  else if (bit_mask[3:0] != 4'b0)
    if (bit_mask[4])
      ram[ram_addr] <= ram[ram_addr] | bit_mask[3:0];
    else
      ram[ram_addr] <= ram[ram_addr] & bit_mask[3:0];
  ram_dout <= ram[ram_addr];
end

// ram we
always @(posedge clk) begin
  ram_we <= 1'b1;
  if (state == FT2)
    casez (op)
      8'b0001_?1??, // EXCI EXCD
      8'b0001_00??: // EXC
        ram_we <= 1'b0;
    endcase
end

// ram_din
always @(posedge clk)
  if (state == FT1)
    casez (op)
      8'b0001_?1??, // EXCI EXCD
      8'b0001_00??: // EXC
        ram_din <= A;
    endcase

// ram bit_mask
always @(posedge clk)
  if (state == FT1)
    casez (op)
      8'b0000_01??: // RM
        bit_mask <= { 1'b0, ~(4'b1 << op[1:0]) };
      8'b0000_11??: // SM
        bit_mask <= { 1'b1, (4'b1 << op[1:0]) };
      default:
        bit_mask <= 5'b0;
    endcase

// ram_addr
always @* begin
  ram_addr = { Bm, Bl };
  if (sbm) ram_addr = { 1'b1, Bm[1:0], Bl };
end

// sbm
always @*
  if (prev_op == 8'b0000_0010 && state != SKP)
    sbm = 1'b1;
  else
    sbm = 1'b0;

// alu
always @* begin
  alu_cy = 1'b0;
  alu_r = 4'b0;
  case (alu_op)
    2'b00: { alu_cy, alu_r } = alu_a + alu_b;
    2'b01: { alu_cy, alu_r } = alu_a - alu_b;
    2'b10: { alu_cy, alu_r } = alu_a + alu_b + 4'(C);
    2'b11: { alu_r, alu_cy } = { C, alu_a };
  endcase
end

// alu a
always @*
  if (state == FT2)
    casez (op)
      8'b0110_?100, // INCB DECB
      8'b0001_?1??: // EXCI EXCD
        alu_a = Bl;
      8'b0110_1011, // ROT
      8'b0011_????, // ADX
      8'b0000_100?: // ADD ADD11
        alu_a = A;
    endcase

// alu b
always @*
  if (state == FT2)
    casez (op)
      8'b0001_?1??, // EXCI EXCD
      8'b0110_?100: // INCB DECB
        alu_b = 4'b1;
      8'b0000_100?: // ADD ADD11
        alu_b = ram_dout;
      8'b0011_????: // ADX
        alu_b = op[3:0];
    endcase

// alu op
always @(posedge clk_32k)
  if (state == FT1)
    casez (op)
      8'b0001_?1??, // EXCI EXCD
      8'b0110_?100: // INCB DECB
        alu_op <= 2'(op[3]);
      8'b0011_????, // ADX
      8'b0000_1000: // ADD
        alu_op <= 2'b0;
      8'b0000_1001: // ADD11
        alu_op <= 2'b10;
      8'b0110_1011: // ROT
        alu_op <= 2'b11;
    endcase

// C
always @(posedge clk_32k)
  if (state == FT2)
    casez (op)
      8'b0110_011?: // RC SC
        C <= op[0];
      8'b0110_1011, // ROT
      8'b0000_1001: // ADD11
        C <= alu_cy;
    endcase

// op
always @*
  op = rom_dout;

// previous op
always @(posedge clk_32k)
  if (state == FT2)
    prev_op <= op;

// W shift register
always @(posedge clk_32k)
  if (state == FT2)
    if (op[7:1] == 7'b0110_001) // WR WS
      W <= { W[6:0], op[0] };

// I/O: BP L Y R'
always @(posedge clk_32k)
  case (op)
    8'b0000_0001: BP <= A; // ATBP
    8'b0101_1001: L <= A; // ATL
    8'b0110_0000: Y <= A; // ATFC
    8'b0110_0001: RP <= A[1:0]; // ATR
    default: begin
      BP <= 4'b1;
    end
  endcase


// R
// R0/R1 have inverted phase
// TODO: dbg in verilator
always @(posedge clk_io) begin
  R[0] = RP[0] ? ~R[0] : 1'b0;
  R[1] = RP[1] & RP[0] ? ~R[0] : (RP[1] ? ~R[1] : 1'b0); // unused
end


// BC (crystal bleeder current, active low)
always @(posedge clk_32k)
  if (op == 8'b0110_1101)
    BC <= C;

// PC & stack (PC => S => R)
always @(posedge clk_32k)
  if (rst)
    { Pu, Pm, Pl } <= { 2'd3, 4'd7, 6'd0 };
  else if (halt)
    { Pu, Pm, Pl } <= { 2'd1, 4'd0, 6'd0 };
  else begin
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
always @(posedge clk_32k) begin
  if (state == FT1) begin
    if (op[7:4] == 4'b0010 && op[7:4] != prev_op[7:4]) A <= op[3:0]; // LAX
  end
  else if (state == FT2)
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
        A <= A ^ 4'hf;
    endcase
end

// Bl
always @(posedge clk_32k)
  case (state)
    FT2:
      casez (op)
        8'b0100_????: begin // LB
          Bl <= {  op[3]|op[2], op[3]|op[2], op[3:2] };
        end
        8'b0000_1011: // EXBLA
          Bl <= A;
        8'b0110_?100, // INCB DECB
        8'b0001_11??, // EXCD
        8'b0001_01??: // EXCI
          Bl <= alu_r;
      endcase
    FT3:
      casez (prev_op)
        8'b0101_1111: // LBL
          Bl <= rom_dout[3:0];
      endcase
  endcase

// Bm
always @(posedge clk_32k)
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

// tis_read
always @(posedge clk_32k)
  if (state == FT2) begin
    if (~Gamma) tis_read <= 1'b0;
    else if (op == 8'b0101_1000) tis_read <= 1'b1; // TIS
  end

// fsm
always @(posedge clk_32k)
  if (~rst | ~halt) begin
    state <= FT1;
    if (state == FT1) state <= FT2;
    else if (state == SKP) state <= SK2;
    else if (state == FT3) state <= FT4; // stupid, todo: implement memory access w/ locks
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
          state <= alu_cy && op[3:0] != 4'hA ? SKP : FT1; // why 0xA?
        8'b0000_1001, // ADD11
        8'b0001_?1??, // EXCI/D
        8'b0110_?100: // INCB DECB
          state <= alu_cy ? SKP : FT1;
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


endmodule