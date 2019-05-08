module usbcore_debug (
    inout  wire         rst_btn,

    input  wire         phy_clk,
    output wire         phy_rst,
    
    input  wire         phy_dir,
    input  wire         phy_nxt,
    output wire         phy_stp,
    inout  wire [7:0]   phy_data
);

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

wire         rx_data;
wire [1:0]   rx_data_type;

wire         rx_data_error;
wire [7:0]   rx_data_tdata;
wire         rx_data_tlast;
wire         rx_data_tvalid;
wire         rx_data_tready;

wire         tx_ready;

wire         tx_ack;
wire         tx_nack;
wire         tx_stall;
wire         tx_nyet;

wire         tx_data;
wire         tx_data_null;
wire [1:0]   tx_data_type;

wire [7:0]   tx_data_tdata;
wire         tx_data_tlast;
wire         tx_data_tvalid;
wire         tx_data_tready;

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
    
    .rx_data(rx_data),
    .rx_data_type(rx_data_type),
    
    .rx_data_error(rx_data_error),
    .rx_data_tdata(rx_data_tdata),
    .rx_data_tlast(rx_data_tlast),
    .rx_data_tvalid(rx_data_tvalid),
    .rx_data_tready(rx_data_tready),
    
    .tx_ready(tx_ready),
    
    .tx_ack(tx_ack),
    .tx_nack(tx_nack),
    .tx_stall(tx_stall),
    .tx_nyet(tx_nyet),
    
    .tx_data(tx_data),
    .tx_data_null(tx_data_null),
    .tx_data_type(tx_data_type),
    
    .tx_data_tdata(tx_data_tdata),
    .tx_data_tlast(tx_data_tlast),
    .tx_data_tvalid(tx_data_tvalid),
    .tx_data_tready(tx_data_tready)
);

wire  [3:0]  ctl_endpoint;
wire  [7:0]  ctl_request_type;
wire  [7:0]  ctl_request;
wire  [15:0] ctl_value;
wire  [15:0] ctl_index;
wire  [15:0] ctl_length;
wire         ctl_start;

wire [7:0]   xfer_rx_tdata;
wire         xfer_rx_tlast;
wire         xfer_rx_error;
wire         xfer_rx_tvalid;
wire         xfer_rx_tready;

wire [7:0]   xfer_tx_tdata;
wire         xfer_tx_tlast;
wire         xfer_tx_tvalid;
wire         xfer_tx_tready;

usb_xfer XFER (
    .clk(ulpi_clk),
    .rst(ulpi_rst | usb_reset),
    
    .rx_in_token(rx_in_token),
    .rx_out_token(rx_out_token),
    .rx_setup_token(rx_setup_token),
    .rx_addr(rx_addr),
    .rx_endpoint(rx_endpoint),
    
    .rx_ack(rx_ack),
    .rx_nack(rx_nack),
    .rx_stall(rx_stall),
    .rx_nyet(rx_nyet),
    
    .rx_data(rx_data),
    .rx_data_type(rx_data_type),
    
    .rx_data_error(rx_data_error),
    .rx_data_tdata(rx_data_tdata),
    .rx_data_tlast(rx_data_tlast),
    .rx_data_tvalid(rx_data_tvalid),
    .rx_data_tready(rx_data_tready),
    
    .tx_ready(tx_ready),
    
    .tx_ack(tx_ack),
    .tx_nack(tx_nack),
    .tx_stall(tx_stall),
    .tx_nyet(tx_nyet),
    
    .tx_data(tx_data),
    .tx_data_null(tx_data_null),
    .tx_data_type(tx_data_type),
    
    .tx_data_tdata(tx_data_tdata),
    .tx_data_tlast(tx_data_tlast),
    .tx_data_tvalid(tx_data_tvalid),
    .tx_data_tready(tx_data_tready),

    .ctl_endpoint(ctl_endpoint),
    .ctl_request_type(ctl_request_type),
    .ctl_request(ctl_request),
    .ctl_value(ctl_value),
    .ctl_index(ctl_index),
    .ctl_length(ctl_length),
    .ctl_start(ctl_start),
    
    .xfer_rx_tdata(xfer_rx_tdata),
    .xfer_rx_tlast(xfer_rx_tlast),
    .xfer_rx_error(xfer_rx_error),
    .xfer_rx_tvalid(xfer_rx_tvalid),
    .xfer_rx_tready(xfer_rx_tready),
    
    .xfer_tx_tdata(xfer_tx_tdata),
    .xfer_tx_tlast(xfer_tx_tlast),
    .xfer_tx_tvalid(xfer_tx_tvalid),
    .xfer_tx_tready(xfer_tx_tready)
);

reg [7:0] DESCRIPTOR[36] = '{
    8'h12,          // bLength = 18
    8'h01,          // bDescriptionType = Device Descriptor
    8'h10, 8'h01,   // bcdUSB = USB 1.1
    8'hFF,          // bDeviceClass = None
    8'h00,          // bDeviceSubClass
    8'h00,          // bDeviceProtocol
    8'h40,          // bMaxPacketSize = 64
    8'h09, 8'h12,   // idVendor
    8'hDB, 8'h05,   // idProduct
    8'h00, 8'h00,   // bcdDevice
    8'h00,          // iManufacturer
    8'h00,          // iProduct
    8'h00,          // iSerialNumber
    8'h01,          // bNumConfigurations = 1
    
    8'h09,          // bLength = 9
    8'h02,          // bDescriptionType = Configuration Descriptor
    8'h12, 8'h00,   // wTotalLength = 18
    8'h01,          // bNumInterfaces = 1
    8'h01,          // bConfigurationValue
    8'h00,          // iConfiguration
    8'hC0,          // bmAttributes = Self-powered
    8'h32,          // bMaxPower = 100 mA
                    // Interface descriptor
    8'h09,          // bLength = 9
    8'h04,          // bDescriptorType = Interface Descriptor
    8'h00,          // bInterfaceNumber = 0
    8'h00,          // bAlternateSetting
    8'h00,          // bNumEndpoints = 0
    8'h00,          // bInterfaceClass
    8'h00,          // bInterfaceSubClass
    8'h00,          // bInterfaceProtocol
    8'h00           // iInterface
};

reg  [5:0] tx_xfer_address = 6'b000000;
reg  [5:0] tx_xfer_max_address = 6'b000000;

 
always @(posedge ulpi_clk) begin
    if (ctl_start)
        if (ctl_value[15:8] == 8'h01) begin
            tx_xfer_address <= 0;
            tx_xfer_max_address <= ctl_length - 1;
        end else if (ctl_value[15:8] == 8'h02) begin
            tx_xfer_address <= 18;
            tx_xfer_max_address <= ctl_length + 18 - 1;
        end else begin
            tx_xfer_address <= 0;
            tx_xfer_max_address <= 35;
        end
    else if (xfer_tx_tvalid & xfer_tx_tready)
        tx_xfer_address <= tx_xfer_address + 1;
end

assign xfer_tx_tvalid = 1'b1;  
assign xfer_tx_tdata = DESCRIPTOR[tx_xfer_address];  
assign xfer_tx_tlast = (tx_xfer_address == tx_xfer_max_address);    

assign xfer_rx_tready = 1'b1;

debug_vio VIO (
    .clk(ulpi_clk),
    .probe_out0(usb_enable)
);

endmodule
