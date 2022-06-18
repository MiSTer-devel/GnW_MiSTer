
module hvgen (
  input vclk,
  output reg hb = 1,
  output reg vb = 1,
  output reg hs = 1,
  output reg vs = 1,
  output ce_pix,
  output reg [9:0] hcnt,
  output reg [9:0] vcnt
);

assign ce_pix = 1'b1;

always @(posedge vclk) begin
	  hcnt <= hcnt + 10'd1;
	  case (hcnt)
		 359: hb <= 1'b1;
		 391: hs <= 1'b0;
		 415: hs <= 1'b1;
		 479: begin
			vcnt <= vcnt + 10'd1;
			hcnt <= 10'd0;
			hb <= 1'b0;
			case (vcnt)
			  239: vb <= 1'b1;
			  251: vs <= 1'b0;
			  269: vs <= 1'b1;
			  275: begin
				 vcnt <= 10'd0;
				 vb <= 1'b0;
			  end
			endcase
		 end
	  endcase
	  
end

endmodule
