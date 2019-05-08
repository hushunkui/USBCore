module usb_xfer (
    input  wire         clk,
    input  wire         rst,

    input  wire         rx_in_token,
    input  wire         rx_out_token,
    input  wire         rx_setup_token,
    input  wire [6:0]   rx_addr,
    input  wire [3:0]   rx_endpoint,
    
    input  wire         rx_ack,
    input  wire         rx_nack,
    input  wire         rx_stall,
    input  wire         rx_nyet,
    
    input  wire         rx_data,
    input  wire [1:0]   rx_data_type,
    
    input  wire         rx_data_error,
    input  wire [7:0]   rx_data_tdata,
    input  wire         rx_data_tlast,
    input  wire         rx_data_tvalid,
    output reg          rx_data_tready,
    
    input  wire         tx_ready,
    
    output reg          tx_ack,
    output wire         tx_nack,
    output wire         tx_stall,
    output wire         tx_nyet,
    
    output wire         tx_data,
    output wire         tx_data_null,
    output reg  [1:0]   tx_data_type,
    
    output wire [7:0]   tx_data_tdata,
    output wire         tx_data_tlast,
    output wire         tx_data_tvalid,
    input  wire         tx_data_tready,
    
    output reg  [3:0]   ctl_endpoint,
    output reg  [7:0]   ctl_request_type,
    output reg  [7:0]   ctl_request,
    output reg  [15:0]  ctl_value,
    output reg  [15:0]  ctl_index,
    output reg  [15:0]  ctl_length,
    output wire         ctl_start,
    
    output wire [7:0]   xfer_rx_tdata,
    output wire         xfer_rx_tlast,
    output wire         xfer_rx_error,
    output wire         xfer_rx_tvalid,
    input  wire         xfer_rx_tready,
   
    input  wire [7:0]   xfer_tx_tdata,
    input  wire         xfer_tx_tlast,
    input  wire         xfer_tx_tvalid,
    output wire         xfer_tx_tready
);

localparam S_IDLE = 0, S_CTL_SETUP_DATA = 2, S_CTL_SETUP_ACK = 3, 
           S_CTL_DATA_TOKEN = 4, S_CTL_DATA_START = 5, S_CTL_DATA = 6, S_CTL_DATA_ACK = 7,
           S_CTL_STATUS_TOKEN = 8, S_CTL_STATUS_DATA_START = 9, S_CTL_STATUS_DATA = 10, 
           S_CTL_STATUS_ACK = 11;

reg  [3:0]  state;
wire        rx_data_strobe;
reg  [15:0] rx_data_counter;
wire        ctl_request_in;
reg  [15:0] tx_data_counter;

assign ctl_request_in = ctl_request_type[7];
assign rx_data_strobe = rx_data_tvalid & rx_data_tready;

always @(posedge clk) begin
    if (rst)
        state <= S_IDLE;
    else case (state)
    S_IDLE:
        if (rx_setup_token)
            state <= S_CTL_SETUP_DATA;
            
    S_CTL_SETUP_DATA:
        if (rx_data_strobe & rx_data_tlast & ~rx_data_error)
            state <= S_CTL_SETUP_ACK;
    
    S_CTL_SETUP_ACK:
        if (tx_ready) begin
            if (ctl_length != 16'h0000)
                state <= S_CTL_DATA_TOKEN;
            else 
                state <= S_CTL_STATUS_TOKEN;
        end
            
    S_CTL_DATA_TOKEN:
        if (rx_in_token)
            state <= S_CTL_DATA_START;
        else if (rx_out_token)
            state <= S_CTL_DATA;
    
    S_CTL_DATA_START:
        if (tx_ready)
            state <= S_CTL_DATA;
    
    S_CTL_DATA:
        if (ctl_request_in & tx_data_tvalid & tx_data_tready & tx_data_tlast)
            state <= S_CTL_DATA_ACK;
        else if (~ctl_request_in & rx_data_tvalid & rx_data_tready & rx_data_tlast)
            state <= S_CTL_DATA_ACK;
    
    S_CTL_DATA_ACK:
        if (ctl_request_in ? rx_ack : tx_ready)
            state <= S_CTL_STATUS_TOKEN;
    
    S_CTL_STATUS_TOKEN:
        if (rx_out_token)
            state <= S_CTL_STATUS_DATA;
        else if (rx_in_token)
            state <= S_CTL_STATUS_DATA_START;
    
    S_CTL_STATUS_DATA_START:
        if (tx_ready)
            state <= S_CTL_STATUS_ACK;
            
    S_CTL_STATUS_DATA:
        if (ctl_request_in ? rx_data : tx_ready)
            state <= S_CTL_STATUS_ACK;

    S_CTL_STATUS_ACK:
        if (ctl_request_in ? tx_ready : rx_ack)
            state <= S_IDLE;
        
    endcase
end

always @(posedge clk)
    if (rst)
        rx_data_counter <= 16'h0000;
    else if ((state == S_IDLE) | (state == S_CTL_SETUP_ACK))
        rx_data_counter <= 16'h0000;
    else if (rx_data_tvalid & rx_data_tready)
        rx_data_counter <= rx_data_counter + 1;        

always @(posedge clk)
    if (rst)
        tx_data_counter <= 16'h0000;
    else if (state == S_CTL_SETUP_ACK)
        tx_data_counter <= 16'h0000;
    else if (tx_data_tvalid & tx_data_tready)
        tx_data_counter <= tx_data_counter + 1;  
        
always @(*) begin
    case (state)
    S_CTL_SETUP_DATA:   rx_data_tready <= 1'b1;
    S_CTL_DATA:         rx_data_tready <= ctl_request_in ? 1'b0 : xfer_rx_tready;
    S_CTL_STATUS_DATA:  rx_data_tready <= ctl_request_in ? 1'b1 : 1'b0;
    default:            rx_data_tready <= 1'b0;
    endcase
end

always @(*) begin
    case (state)
    S_CTL_SETUP_ACK:    tx_ack <= 1'b1;
    S_CTL_DATA_ACK:     tx_ack <= ctl_request_in ? 1'b0 : 1'b1;
    S_CTL_STATUS_ACK:   tx_ack <= ctl_request_in ? 1'b1 : 1'b0;
    default:            tx_ack <= 1'b0;
    endcase
end

assign tx_nack = 1'b0;
assign tx_stall = 1'b0;
assign tx_nyet = 1'b0;

assign tx_data = (state == S_CTL_DATA_START) | (state == S_CTL_STATUS_DATA_START);
assign tx_data_null = (state == S_CTL_STATUS_DATA_START);

always @(posedge clk)
    if (state == S_CTL_SETUP_ACK)
        tx_data_type <= 2'b10;
    else if (tx_data_tvalid & tx_data_tready & tx_data_tlast)
        tx_data_type[1] <= ~tx_data_type[1];
        
assign tx_data_tdata = xfer_tx_tdata;
assign tx_data_tlast = xfer_tx_tlast | (tx_data_counter[5:0] == 6'b111111);
assign tx_data_tvalid = (state == S_CTL_DATA) & ctl_request_in & xfer_tx_tvalid;

assign ctl_start = (state == S_CTL_SETUP_ACK);

always @(posedge clk) begin
    if ((state == S_IDLE) & rx_setup_token)
        ctl_endpoint <= rx_endpoint;
        
    if ((state == S_CTL_SETUP_DATA) & rx_data_strobe) begin
        case (rx_data_counter)
        9'h000: ctl_request_type <= rx_data_tdata;
        9'h001: ctl_request <= rx_data_tdata;
        9'h002: ctl_value[7:0] <= rx_data_tdata;
        9'h003: ctl_value[15:8] <= rx_data_tdata;
        9'h004: ctl_index[7:0] <= rx_data_tdata;
        9'h005: ctl_index[15:8] <= rx_data_tdata;
        9'h006: ctl_length[7:0] <= rx_data_tdata;
        9'h007: ctl_length[15:8] <= rx_data_tdata;
        endcase
    end
end

assign xfer_rx_tdata = rx_data_tdata;
assign xfer_rx_error = rx_data_error;
assign xfer_rx_tlast = rx_data_counter == (ctl_length - 1);
assign xfer_rx_tvalid = (state == S_CTL_DATA) & ~ctl_request_in & rx_data_tvalid;

assign xfer_tx_tready = ((state == S_CTL_DATA) & ctl_request_in) ? tx_data_tready : 1'b0;

endmodule
