
module hvgen (
  input vclk,
  output reg hb = 1,
  output reg vb = 1,
  output reg hs = 1,
  output reg vs = 1,
  output reg ce_pix,
  output reg [9:0] hcnt,
  output reg [9:0] vcnt
);

// 720x480 27MHz

always @(posedge vclk) begin
  ce_pix <= ~ce_pix;
  hcnt <= hcnt + 1'b1;
  case (hcnt)
    719: hb <= 1'b1;
    736: hs <= 1'b0;
    799: hs <= 1'b1;
    858: begin
      vcnt <= vcnt + 1'b1;
      hcnt <= 1'b0;
      hb <= 1'b0;
      case (vcnt)
        479: vb <= 1'b1;
        486: vs <= 1'b0;
        492: vs <= 1'b1;
        525: begin
          vcnt <= 1'b0;
          vb <= 1'b0;
        end
      endcase
    end
  endcase
end

endmodule
