
module rom_decode(
  input clk_sys,

  input [24:0] ioctl_addr,
  input ioctl_download,
  input [7:0] ioctl_dout,

  output reg conf,
  output reg palette,
  output reg rom,

  output reg [7:0] mcuid,
  output reg [24:0] image_addr,
  output reg [24:0] rom_addr
);

reg [3:0] state = 0;
reg [31:0] bytes_to_read, buffer;

parameter
  START = 4'd0,
  CONFIG_DATA = 4'd2,
  IMG_SIZE = 4'd3,
  IMG_DATA = 4'd4,
  PAL_DATA = 4'd5,
  ROM_DATA = 4'd6,
  IDLE = 4'd7;

reg ioctl_old_download;
reg [24:0] ioctl_old_addr;

always @(posedge clk_sys) begin
  ioctl_old_addr <= ioctl_addr;
  ioctl_old_download <= ioctl_download;
  if (ioctl_addr == 25'd0) mcuid <= ioctl_dout;

  if (state == IDLE) begin
    state <= ~ioctl_old_download & ioctl_download ? START : IDLE;
  end

  if (ioctl_old_addr != ioctl_addr) begin
    buffer <= { buffer[23:0], ioctl_dout };
    if (bytes_to_read > 0) bytes_to_read <= bytes_to_read - 32'd1;
    case (state)
      START: begin
        if (ioctl_addr == 25'd1) begin
          bytes_to_read <= ioctl_dout;
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
          image_addr <= ioctl_addr;
        end
      end
      IMG_DATA: begin
        if (bytes_to_read == 0) begin
          state <= PAL_DATA;
          bytes_to_read <= 256*3-1;
          palette <= 1'b1;
        end
      end
      PAL_DATA: begin
        if (bytes_to_read == 0) begin
          state <= ROM_DATA;
          bytes_to_read <= 32'hfff;
          palette <= 1'b0;
          rom <= 1'b1;
          rom_addr <= ioctl_addr;
        end
      end
      ROM_DATA: begin
        if (bytes_to_read == 0) begin
          state <= IDLE;
          rom <= 1'b0;
        end
      end
    endcase
  end
end

endmodule
