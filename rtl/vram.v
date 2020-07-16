
module vram (
  input clk,
  input [18:0] addr_rd,
  input [18:0] addr_wr,
  input [7:0] din,
  output reg [7:0] dout,
  input we
);

reg [7:0] memory[640*480-1:0];

always @(posedge clk)
  if (we) memory[addr_wr] <= din;

always @(posedge clk)
  dout <= memory[addr_rd];
  
endmodule
