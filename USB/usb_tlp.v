module usb_tlp (
    input  wire         clk,
    input  wire         rst,
        
    input  wire [7:0]   rx_tdata,
    input  wire         rx_tlast,
    input  wire         rx_tvalid,
    output wire         rx_tready,
    
    output wire [7:0]   tx_tdata,
    output wire         tx_tlast,
    output wire         tx_tvalid,
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
    
    output reg  [1:0]   rx_data_type,
    output wire         rx_data_error,
    output wire [7:0]   rx_data_tdata,
    output wire         rx_data_tlast,
    output wire         rx_data_tvalid,
    input  wire         rx_data_tready,
    
    input wire          tx_ack,
    input wire          tx_nack,
    input wire          tx_stall,
    input wire          tx_nyet
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
    crc16[0]  = d[0] ^ d[1] ^ d[2] ^ d[3] ^ d[4] ^ d[5] ^ d[6] ^ d[7] ^ c[8] ^ c[9] ^ c[10] ^ c[11] ^ c[12] ^ c[13] ^ c[14] ^ c[15];
    crc16[1]  = d[0] ^ d[1] ^ d[2] ^ d[3] ^ d[4] ^ d[5] ^ d[6] ^ c[9] ^ c[10] ^ c[11] ^ c[12] ^ c[13] ^ c[14] ^ c[15];
    crc16[2]  = d[6] ^ d[7] ^ c[8] ^ c[9];
    crc16[3]  = d[5] ^ d[6] ^ c[9] ^ c[10];
    crc16[4]  = d[4] ^ d[5] ^ c[10] ^ c[11];
    crc16[5]  = d[3] ^ d[4] ^ c[11] ^ c[12];
    crc16[6]  = d[2] ^ d[3] ^ c[12] ^ c[13];
    crc16[7]  = d[1] ^ d[2] ^ c[13] ^ c[14];
    crc16[8]  = d[0] ^ d[1] ^ c[0] ^ c[14] ^ c[15];
    crc16[9]  = d[0] ^ c[1] ^ c[15];
    crc16[10] = c[2];
    crc16[11] = c[3];
    crc16[12] = c[4];
    crc16[13] = c[5];
    crc16[14] = c[6];
    crc16[15] = d[0] ^ d[1] ^ d[2] ^ d[3] ^ d[4] ^ d[5] ^ d[6] ^ d[7] ^ c[7] ^ c[8] ^ c[9] ^ c[10] ^ c[11] ^ c[12] ^ c[13] ^ c[14] ^ c[15];
end endfunction

localparam S_RX_PID = 0, S_RX_TKN_ADDR = 1, S_RX_TKN_EPCRC = 2, S_RX_SIG_OUT = 3, S_RX_DATA = 4, 
           S_RX_UNKNOWN = 5;

localparam S_TX_IDLE = 0, S_TX_ACK_PID = 1;
           
reg  [2:0]      rx_state;
wire            rx_strobe;
reg  [3:0]      rx_pid;
reg  [7:0]      rx_tdata_prev;
wire [4:0]      rx_crc5;
wire            rx_crc5_valid;
reg             rx_crc_en;
reg  [15:0]     rx_crc16;

reg  [2:0]      tx_state;
wire            tx_strobe;
reg  [3:0]      tx_pid;

assign rx_strobe = rx_tvalid & rx_tready;
assign tx_strobe = tx_tvalid & tx_tready;

always @(posedge clk)
    if (rx_strobe)
        rx_tdata_prev <= rx_tdata;

assign rx_crc5 = crc5({rx_tdata[2:0], rx_tdata_prev});
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

// One clock delay for CRC-16 calculation
always @(posedge clk)
    if (rst)
        rx_crc_en <= 1'b0;
    else if ((rx_state == S_RX_DATA) & rx_strobe)
        rx_crc_en <= 1'b1;
    else if (rx_state != S_RX_DATA)
        rx_crc_en <= 1'b0;
        
always @(posedge clk)
    if (rx_state != S_RX_DATA)
        rx_crc16 <= 16'hFFFF;
    else if (rx_crc_en & rx_strobe)
        rx_crc16 <= crc16(rx_tdata_prev, rx_crc16);

always @(posedge clk)
    if ((rx_state == S_RX_PID) & rx_strobe & (rx_tdata[1:0] == 2'b11))
        rx_data_type <= rx_tdata[3:2];

assign rx_data_error = rx_data_tlast & (rx_crc16 != {rx_tdata_prev, rx_tdata});
assign rx_data_tdata = rx_tdata;
assign rx_data_tlast = rx_tlast;
assign rx_data_tvalid = rx_tvalid & (rx_state == S_RX_DATA);
    
assign rx_tready = (rx_state == S_RX_DATA) ? rx_data_tready : (rx_state != S_RX_SIG_OUT);

assign rx_in_token = (rx_state == S_RX_SIG_OUT) & (rx_pid == 4'b1001);
assign rx_out_token = (rx_state == S_RX_SIG_OUT) & (rx_pid == 4'b0001);
assign rx_setup_token = (rx_state == S_RX_SIG_OUT) & (rx_pid == 4'b1101);
assign rx_sof = (rx_state == S_RX_SIG_OUT) & (rx_pid == 4'b0101);

assign rx_ack = (rx_state == S_RX_SIG_OUT) & (rx_pid == 4'b0010);
assign rx_nack = (rx_state == S_RX_SIG_OUT) & (rx_pid == 4'b0110);
assign rx_stall = (rx_state == S_RX_SIG_OUT) & (rx_pid == 4'b1010);
assign rx_nyet = (rx_state == S_RX_SIG_OUT) & (rx_pid == 4'b1110);

always @(posedge clk) begin
    if (rst)
        tx_state <= S_TX_IDLE;
    else case (tx_state)
    S_TX_IDLE:
        if (tx_ack | tx_nack | tx_stall | tx_nyet)
            tx_state <= S_TX_ACK_PID;
            
    S_TX_ACK_PID:
        if (tx_strobe)
            tx_state <= S_TX_IDLE;
        
    endcase
end

always @(posedge clk) 
    if ((tx_state == S_TX_IDLE) & tx_ack)
        tx_pid <= 4'b0010;
    else if ((tx_state == S_TX_IDLE) & tx_nack)
        tx_pid <= 4'b0110;
    else if ((tx_state == S_TX_IDLE) & rx_stall)
        tx_pid <= 4'b1010;
    else if ((tx_state == S_TX_IDLE) & rx_nyet)
        tx_pid <= 4'b1110;
        
assign tx_tdata = {~tx_pid, tx_pid};
assign tx_tlast = (tx_state == S_TX_ACK_PID) ? 1'b1 : 1'b0;
assign tx_tvalid = (tx_state == S_TX_ACK_PID) ? 1'b1 : 1'b0;
        
endmodule
