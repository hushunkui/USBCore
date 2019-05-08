module usb_tlp (
    input  wire         clk,
    input  wire         rst,
        
    input  wire [7:0]   rx_tdata,
    input  wire         rx_tlast,
    input  wire         rx_tvalid,
    output wire         rx_tready,
    
    output reg  [7:0]   tx_tdata,
    output reg          tx_tlast,
    output reg          tx_tvalid,
    input  wire         tx_tready,
    
    output wire         rx_in_token,
    output wire         rx_out_token,
    output wire         rx_setup_token,
    output reg  [6:0]   rx_addr,
    output reg  [3:0]   rx_endpoint,
    
    output wire         rx_ack,
    output wire         rx_nack,
    output wire         rx_stall,
    output wire         rx_nyet,
    
    output wire         rx_sof,
    output reg  [10:0]  rx_frame_number,
    
    output wire         rx_data,
    output reg  [1:0]   rx_data_type,
    
    output wire         rx_data_error,
    output wire [7:0]   rx_data_tdata,
    output wire         rx_data_tlast,
    output wire         rx_data_tvalid,
    input  wire         rx_data_tready,
    
    output wire         tx_ready,
    
    input  wire         tx_ack,
    input  wire         tx_nack,
    input  wire         tx_stall,
    input  wire         tx_nyet,
    
    input  wire         tx_data,
    input  wire         tx_data_null,
    input  wire [1:0]   tx_data_type,
    
    input  wire [7:0]   tx_data_tdata,
    input  wire         tx_data_tlast,
    input  wire         tx_data_tvalid,
    output wire         tx_data_tready
);

function [4:0] crc5;
    input [10:0] data;
begin
    crc5[4] = ~(1'b1 ^ data[10] ^ data[7] ^ data[5] ^ data[4] ^ data[1] ^ data[0]);
    crc5[3] = ~(1'b1 ^ data[9]  ^ data[6] ^ data[4] ^ data[3] ^ data[0]);
    crc5[2] = ~(1'b1 ^ data[10] ^ data[8] ^ data[7] ^ data[4] ^ data[3] ^ data[2] ^ data[1] ^ data[0]);
    crc5[1] = ~(1'b0 ^ data[9]  ^ data[7] ^ data[6] ^ data[3] ^ data[2] ^ data[1] ^ data[0]);
    crc5[0] = ~(1'b1 ^ data[8]  ^ data[6] ^ data[5] ^ data[2] ^ data[1] ^ data[0]);
end endfunction

function [15:0] crc16;
    input [7:0]  d;
    input [15:0] c;
begin
    crc16[ 0] = d[0] ^ d[1] ^ d[2] ^ d[3] ^ d[4] ^ d[5] ^ d[6] ^ d[7] ^ c[8] ^ c[9] ^ c[10] ^ c[11] ^ c[12] ^ c[13] ^ c[14] ^ c[15];
    crc16[ 1] = d[0] ^ d[1] ^ d[2] ^ d[3] ^ d[4] ^ d[5] ^ d[6] ^ c[9] ^ c[10] ^ c[11] ^ c[12] ^ c[13] ^ c[14] ^ c[15];
    crc16[ 2] = d[6] ^ d[7] ^ c[8] ^ c[9];
    crc16[ 3] = d[5] ^ d[6] ^ c[9] ^ c[10];
    crc16[ 4] = d[4] ^ d[5] ^ c[10] ^ c[11];
    crc16[ 5] = d[3] ^ d[4] ^ c[11] ^ c[12];
    crc16[ 6] = d[2] ^ d[3] ^ c[12] ^ c[13];
    crc16[ 7] = d[1] ^ d[2] ^ c[13] ^ c[14];
    crc16[ 8] = d[0] ^ d[1] ^ c[0] ^ c[14] ^ c[15];
    crc16[ 9] = d[0] ^ c[1] ^ c[15];
    crc16[10] = c[2];
    crc16[11] = c[3];
    crc16[12] = c[4];
    crc16[13] = c[5];
    crc16[14] = c[6];
    crc16[15] = d[0] ^ d[1] ^ d[2] ^ d[3] ^ d[4] ^ d[5] ^ d[6] ^ d[7] ^ c[7] ^ c[8] ^ c[9] ^ c[10] ^ c[11] ^ c[12] ^ c[13] ^ c[14] ^ c[15];
end endfunction

localparam S_RX_PID = 0, S_RX_TKN_ADDR = 1, S_RX_TKN_EPCRC = 2, S_RX_SIG_OUT = 3, S_RX_DATA = 4, 
           S_RX_UNKNOWN = 5;

localparam S_TX_IDLE = 0, S_TX_ACK_PID = 1, S_TX_DATA_PID = 2, S_TX_DATA = 3, S_TX_CRC = 4;
           
reg  [2:0]      rx_state;
wire            rx_strobe;
reg  [3:0]      rx_pid;
reg  [7:0]      rx_tdata_prev[0:1];
reg             rx_tdata_prev_valid[0:2];
wire [4:0]      rx_crc5;
wire            rx_crc5_valid;
reg  [15:0]     rx_crc16, rx_crc16_rev;

reg  [2:0]      tx_state;
wire            tx_strobe;
reg  [3:0]      tx_pid;
reg  [15:0]     tx_crc16, tx_crc16_rev;
reg             tx_crc_low;
reg             tx_null;

assign rx_strobe = rx_tvalid & rx_tready;
assign tx_strobe = tx_tvalid & tx_tready;

always @(posedge clk) begin
    if (rx_strobe) begin
        rx_tdata_prev[0] <= rx_tdata;
        rx_tdata_prev[1] <= rx_tdata_prev[0];
    end
end

always @(posedge clk) begin
    if (rx_strobe & rx_tlast) begin
        rx_tdata_prev_valid[0] <= 1'b0;
        rx_tdata_prev_valid[1] <= 1'b0;
        rx_tdata_prev_valid[2] <= 1'b0;
    end else if (rx_strobe) begin
        rx_tdata_prev_valid[0] <= 1'b1;
        rx_tdata_prev_valid[1] <= rx_tdata_prev_valid[0];
        rx_tdata_prev_valid[2] <= rx_tdata_prev_valid[1];
    end
end

assign rx_crc5 = crc5({rx_tdata[2:0], rx_tdata_prev[0]});
assign rx_crc5_valid = rx_tdata[7:3] == rx_crc5;

always @(posedge clk) begin
    if (rst)
        rx_state <= S_RX_PID;
    else case (rx_state)
    S_RX_PID: 
        if (rx_strobe & (rx_tdata[3:0] == ~rx_tdata[7:4])) begin
            casez (rx_tdata[3:0])
            4'b??01:
                rx_state <= S_RX_TKN_ADDR;
                
            4'b??11:
                rx_state <= S_RX_DATA;
                
            4'b??10:
                rx_state <= S_RX_SIG_OUT;
                
            default:
                if (~rx_tlast)
                    rx_state <= S_RX_UNKNOWN;
            endcase
        end else if (rx_strobe & ~rx_tlast)
            rx_state <= S_RX_UNKNOWN;
            
    S_RX_TKN_ADDR:
        if (rx_strobe)
            rx_state <= S_RX_TKN_EPCRC;
        
    S_RX_TKN_EPCRC:
        if (rx_strobe & rx_crc5_valid & rx_tlast)
            rx_state <= S_RX_SIG_OUT;
        else if (rx_strobe & ~rx_tlast)
            rx_state <= S_RX_UNKNOWN;
        else if (rx_strobe)
            rx_state <= S_RX_PID;
            
    S_RX_SIG_OUT:
        rx_state <= S_RX_PID;
        
    S_RX_DATA:
        if (rx_strobe & rx_tlast)
            rx_state <= S_RX_PID;

    S_RX_UNKNOWN:
        if (rx_strobe & rx_tlast)
            rx_state <= S_RX_PID;
        
    endcase
end

always @(posedge clk)
    if ((rx_state == S_RX_PID) & rx_strobe)
        rx_pid <= rx_tdata[3:0];

always @(posedge clk) begin
    if ((rx_pid == 4'b0101) & (rx_state == S_RX_TKN_ADDR) & rx_strobe)
        rx_frame_number[7:0] <= rx_tdata;
    else if ((rx_pid == 4'b0101) & (rx_state == S_RX_TKN_EPCRC) & rx_strobe)
        rx_frame_number[10:8] <= rx_tdata[2:0];
end
    
always @(posedge clk) begin
    if ((rx_pid != 4'b0101) & (rx_state == S_RX_TKN_ADDR) & rx_strobe) begin
        rx_addr <= rx_tdata[6:0];
        rx_endpoint[0] <= rx_tdata[7];
    end else if ((rx_pid != 4'b0101) & (rx_state == S_RX_TKN_EPCRC) & rx_strobe) begin
        rx_endpoint[3:1] <= rx_tdata[2:0];
    end
end
        
always @(posedge clk)
    if (rx_state != S_RX_DATA)
        rx_crc16 <= 16'hFFFF;
    else if (rx_tdata_prev_valid[1] & rx_strobe)
        rx_crc16 <= crc16(rx_tdata_prev[0], rx_crc16);
        
always @(*) begin: RX_CRC_REV
    integer i;
    for (i = 0; i < 16; i = i + 1)
        rx_crc16_rev[i] <= ~rx_crc16[15-i];
end

always @(posedge clk)
    if ((rx_state == S_RX_PID) & rx_strobe & (rx_tdata[1:0] == 2'b11))
        rx_data_type <= rx_tdata[3:2];

assign rx_data_error = rx_data_tlast & (rx_crc16_rev != {rx_tdata, rx_tdata_prev[0]});
assign rx_data_tdata = rx_tdata_prev[1];
assign rx_data_tlast = rx_tlast;
assign rx_data_tvalid = rx_tdata_prev_valid[2] & rx_tvalid & (rx_state == S_RX_DATA);

assign rx_tready = (rx_state == S_RX_DATA) ? rx_data_tready | ~rx_tdata_prev_valid[1] | ~rx_tdata_prev_valid[2] : (rx_state != S_RX_SIG_OUT);

assign rx_in_token = (rx_state == S_RX_SIG_OUT) & (rx_pid == 4'b1001);
assign rx_out_token = (rx_state == S_RX_SIG_OUT) & (rx_pid == 4'b0001);
assign rx_setup_token = (rx_state == S_RX_SIG_OUT) & (rx_pid == 4'b1101);
assign rx_sof = (rx_state == S_RX_SIG_OUT) & (rx_pid == 4'b0101);

assign rx_ack = (rx_state == S_RX_SIG_OUT) & (rx_pid == 4'b0010);
assign rx_nack = (rx_state == S_RX_SIG_OUT) & (rx_pid == 4'b0110);
assign rx_stall = (rx_state == S_RX_SIG_OUT) & (rx_pid == 4'b1010);
assign rx_nyet = (rx_state == S_RX_SIG_OUT) & (rx_pid == 4'b1110);

reg  rx_data_first;
always @(posedge clk)
    if (rst)
        rx_data_first <= 1'b1;
    else if ((rx_state == S_RX_DATA) & rx_data_first)
        rx_data_first <= 1'b0;
    else if (rx_state != S_RX_DATA) 
        rx_data_first <= 1'b1;

assign rx_data = (rx_state == S_RX_DATA) & rx_data_first;

always @(posedge clk) begin
    if (rst)
        tx_state <= S_TX_IDLE;
    else case (tx_state)
    S_TX_IDLE:
        if (tx_ack | tx_nack | tx_stall | tx_nyet)
            tx_state <= S_TX_ACK_PID;
        else if (tx_data)
            tx_state <= S_TX_DATA_PID;
            
    S_TX_ACK_PID:
        if (tx_strobe)
            tx_state <= S_TX_IDLE;
            
    S_TX_DATA_PID:
        if (tx_strobe)
            tx_state <= tx_null ? S_TX_CRC : S_TX_DATA;
    
    S_TX_DATA:
        if (tx_strobe & tx_data_tlast)
            tx_state <= S_TX_CRC;
            
    S_TX_CRC:
        if (tx_strobe & tx_tlast)
            tx_state <= S_TX_IDLE;
        
    endcase
end

always @(posedge clk) 
    if ((tx_state == S_TX_IDLE) & tx_data)
        tx_null <= tx_data_null;

always @(posedge clk) 
    if ((tx_state == S_TX_IDLE) & tx_ack)
        tx_pid <= 4'b0010;
    else if ((tx_state == S_TX_IDLE) & tx_nack)
        tx_pid <= 4'b0110;
    else if ((tx_state == S_TX_IDLE) & tx_stall)
        tx_pid <= 4'b1010;
    else if ((tx_state == S_TX_IDLE) & tx_nyet)
        tx_pid <= 4'b1110;
    else if ((tx_state == S_TX_IDLE) & tx_data)
        tx_pid <= {tx_data_type, 2'b11};
    
always @(posedge clk)
    if (tx_state == S_TX_DATA_PID)
        tx_crc16 <= 16'hFFFF;
    else if (tx_data_tvalid & tx_data_tready)
        tx_crc16 <= crc16(tx_data_tdata, tx_crc16);
        
always @(*) begin: TX_CRC_REV
    integer i;
    for (i = 0; i < 16; i = i + 1)
        tx_crc16_rev[i] <= ~tx_crc16[15-i];
end
    
always @(posedge clk) 
    if (tx_state != S_TX_CRC)
        tx_crc_low <= 1'b1;
    else if (tx_strobe)
        tx_crc_low <= 1'b0;
        
assign tx_ready = (tx_state == S_TX_IDLE);
        
always @(*) begin
    case (tx_state)
    S_TX_ACK_PID, S_TX_DATA_PID:
        tx_tdata = {~tx_pid, tx_pid};
    S_TX_CRC:
        tx_tdata = tx_crc_low ? tx_crc16_rev[7:0] : tx_crc16_rev[15:8];
    default:
        tx_tdata = tx_data_tdata;
    endcase
end
        
always @(*) begin
    case (tx_state)
    S_TX_ACK_PID:   tx_tlast = 1'b1;
    S_TX_CRC:       tx_tlast = ~tx_crc_low;
    default:        tx_tlast = 1'b0;
    endcase
end

always @(*) begin
    case (tx_state)
    S_TX_ACK_PID, S_TX_DATA_PID, S_TX_CRC:   
        tx_tvalid = 1'b1;
    S_TX_DATA: 
        tx_tvalid = tx_data_tvalid;
    default:        
        tx_tvalid = 1'b0;
    endcase
end

assign tx_data_tready = (tx_state == S_TX_DATA) ? tx_tready : 1'b0;

endmodule
