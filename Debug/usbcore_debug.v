module usbcore_debug (
    inout  wire         rst_btn,

    input  wire         phy_clk,
    output wire         phy_rst,
    
    input  wire         phy_dir,
    input  wire         phy_nxt,
    output wire         phy_stp,
    inout  wire [7:0]   phy_data
);

(* keep = "true" *)
wire         ulpi_clk;
wire         ulpi_rst;
wire         ulpi_dir;
wire         ulpi_nxt;
wire         ulpi_stp;
wire [7:0]   ulpi_data_in;
wire [7:0]   ulpi_data_out;

// Dirty
assign ulpi_rst = ~rst_btn;
    
ulpi_io IO (
    .phy_clk        (phy_clk),
    .phy_rst        (phy_rst),
    
    .phy_dir        (phy_dir),
    .phy_nxt        (phy_nxt),
    .phy_stp        (phy_stp),
    .phy_data       (phy_data),
    
    .ulpi_clk       (ulpi_clk),
    .ulpi_rst       (ulpi_rst),
    
    .ulpi_dir       (ulpi_dir),
    .ulpi_nxt       (ulpi_nxt),
    .ulpi_stp       (ulpi_stp),
    .ulpi_data_in   (ulpi_data_in),
    .ulpi_data_out  (ulpi_data_out)
);

wire         usb_enable;
wire         usb_reset;

wire [1:0]   line_state;
wire [1:0]   vbus_state;
wire         rx_active;
wire         rx_error;
wire         host_disconnect;

wire [7:0]   rx_tdata;
wire         rx_tlast;
wire         rx_tvalid;
wire         rx_tready;

wire [7:0]   tx_tdata;
wire         tx_tlast;
wire         tx_tvalid;
wire         tx_tready;
    
wire         reg_en;
wire         reg_rdy;
wire         reg_we;
wire [7:0]   reg_addr;
wire [7:0]   reg_din;
wire [7:0]   reg_dout;

ulpi_ctl ULPI_CONTROLLER (
    .ulpi_clk(ulpi_clk),
    .ulpi_rst(ulpi_rst),
    
    .ulpi_dir(ulpi_dir),
    .ulpi_nxt(ulpi_nxt),
    .ulpi_stp(ulpi_stp),
    .ulpi_data_in(ulpi_data_in),
    .ulpi_data_out(ulpi_data_out),
   
    .line_state(line_state),
    .vbus_state(vbus_state),
    .rx_active(rx_active),
    .rx_error(rx_error),
    .host_disconnect(host_disconnect),
  
    .rx_tdata(rx_tdata),
    .rx_tlast(rx_tlast),
    .rx_tvalid(rx_tvalid),
    .rx_tready(rx_tready),
    
    .tx_tdata(tx_tdata),
    .tx_tlast(tx_tlast),
    .tx_tvalid(tx_tvalid),
    .tx_tready(tx_tready),
    
    .reg_en(reg_en),
    .reg_rdy(reg_rdy),
    .reg_we(reg_we),
    .reg_addr(reg_addr),
    .reg_din(reg_din),
    .reg_dout(reg_dout)
);

usb_state_ctl STATE_CONTROLLER (
    .clk(ulpi_clk),
    .rst(ulpi_rst),
    
    .usb_enable(usb_enable),
    
    .usb_reset(usb_reset),
    
    .vbus_state(vbus_state),
    .line_state(line_state),

    .reg_en(reg_en),
    .reg_rdy(reg_rdy),
    .reg_we(reg_we),
    .reg_addr(reg_addr),
    .reg_din(reg_din),
    .reg_dout(reg_dout)
);

wire         rx_in_token;
wire         rx_out_token;
wire         rx_setup_token;
wire [6:0]   rx_addr;
wire [3:0]   rx_endpoint;

wire         rx_ack;
wire         rx_nack;
wire         rx_stall;
wire         rx_nyet;

wire         rx_sof;
wire [10:0]  rx_frame_number;

wire [1:0]   rx_data_type;
wire         rx_data_error;
wire [7:0]   rx_data_tdata;
wire         rx_data_tlast;
wire         rx_data_tvalid;
wire         rx_data_tready;

reg          tx_ack;
wire         tx_nack;
wire         tx_stall;
wire         tx_nyet;

usb_tlp TLP (
    .clk(ulpi_clk),
    .rst(ulpi_rst | usb_reset),
    
    .rx_tdata(rx_tdata),
    .rx_tlast(rx_tlast),
    .rx_tvalid(rx_tvalid),
    .rx_tready(rx_tready),
    
    .tx_tdata(tx_tdata),
    .tx_tlast(tx_tlast),
    .tx_tvalid(tx_tvalid),
    .tx_tready(tx_tready),

    .rx_in_token(rx_in_token),
    .rx_out_token(rx_out_token),
    .rx_setup_token(rx_setup_token),
    .rx_addr(rx_addr),
    .rx_endpoint(rx_endpoint),
    
    .rx_ack(rx_ack),
    .rx_nack(rx_nack),
    .rx_stall(rx_stall),
    .rx_nyet(rx_nyet),
    
    .rx_sof(rx_sof),
    .rx_frame_number(rx_frame_number),
    
    .rx_data_type(rx_data_type),
    .rx_data_error(rx_data_error),
    .rx_data_tdata(rx_data_tdata),
    .rx_data_tlast(rx_data_tlast),
    .rx_data_tvalid(rx_data_tvalid),
    .rx_data_tready(rx_data_tready),
    
    .tx_ack(tx_ack),
    .tx_nack(tx_nack),
    .tx_stall(tx_stall),
    .tx_nyet(tx_nyet)
);

assign rx_data_tready = 1'b1;

always @(posedge ulpi_clk)
    if (rx_data_tvalid & rx_data_tready & rx_data_tlast)
        tx_ack <= 1'b1;
    else
        tx_ack <= 1'b0;

debug_vio VIO (
    .clk(ulpi_clk),
    .probe_out0(usb_enable)
);

endmodule
