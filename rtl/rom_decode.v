
module rom_decode(
  input clk_sys,
  input [24:0] ioctl_addr,
  input ioctl_download,
  input [7:0] ioctl_dout,
  output [24:0] relative_addr,
  output id,
  output reg conf,
  output reg image,
  output reg palette,
  output reg rom
);

reg [3:0] state;
reg [31:0] bytes_to_read, buffer;
reg [24:0] offset;

parameter
  START = 4'd0,
  CONFIG_DATA = 4'd2,
  IMG_SIZE = 4'd3,
  IMG_DATA = 4'd4,
  PAL_DATA = 4'd5,
  ROM_DATA = 4'd6,
  IDLE = 4'd7;

assign id = ioctl_download && ioctl_addr == 0;
assign relative_addr = ioctl_addr - offset;

reg [24:0] ioctl_new_addr;
always @(posedge clk_sys)
  ioctl_new_addr <= ioctl_addr;

wire new_data = ioctl_addr ^ ioctl_new_addr;

always @(posedge clk_sys) begin
  if (new_data) begin
    buffer <= { buffer[23:0], ioctl_dout };
    if (bytes_to_read != 0) bytes_to_read <= bytes_to_read - 32'd1;
    case (state)
      // WAIT: state <= CONF_SIZE;
      START: begin
        if (ioctl_addr == 25'd1) begin
          bytes_to_read <= ioctl_dout;
          offset <= ioctl_addr;
          state <= CONFIG_DATA;
          conf <= 1'b1;
        end
      end
      CONFIG_DATA: begin
        if (bytes_to_read == 0) begin
          state <= IMG_SIZE;
          bytes_to_read <= 32'd3;
          conf <= 1'b0;
        end
      end
      IMG_SIZE: begin
        if (bytes_to_read == 0) begin
          state <= IMG_DATA;
          bytes_to_read <= buffer;
          offset <= ioctl_addr;
          image <= 1'b1;
        end
      end
      IMG_DATA: begin
        if (bytes_to_read == 0) begin
          state <= PAL_DATA;
          bytes_to_read <= 256*3-1;
          offset <= ioctl_addr;
          image <= 1'b0;
          palette <= 1'b1;
        end
      end
      PAL_DATA: begin
        if (bytes_to_read == 0) begin
          state <= ROM_DATA;
          bytes_to_read <= 32'hfff;
          offset <= ioctl_addr;
          palette <= 1'b0;
          rom <= 1'b1;
        end
      end
      ROM_DATA: begin
        if (bytes_to_read == 0) begin
          state <= IDLE;
          rom <= 1'b0;
        end
      end
      IDLE: state <= IDLE;
    endcase
  end
end

endmodule