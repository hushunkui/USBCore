module ulpi_ctl(
    input  wire         ulpi_clk,
    input  wire         ulpi_rst,
   
    input  wire         ulpi_dir,
    input  wire         ulpi_nxt,
    output wire         ulpi_stp,
    input  wire [7:0]   ulpi_data_in,
    output wire [7:0]   ulpi_data_out,
    
    output wire [1:0]   line_state,
    output wire [1:0]   vbus_state,
    output wire         rx_active,
    output wire         rx_error,
    output wire         host_disconnect,
    
    output wire [7:0]   rx_tdata,
    output wire         rx_tlast,
    output wire         rx_tvalid,
    input  wire         rx_tready, // if tready == 1'b0, packet will be aborted
    
    input  wire [7:0]   tx_tdata,
    input  wire         tx_tlast,
    input  wire         tx_tvalid,
    output wire         tx_tready,
    
    // ULPI PHY registers port, similar to xilinx's DRP
    input  wire         reg_en,
    output wire         reg_rdy,
    input  wire         reg_we,
    input  wire [7:0]   reg_addr,
    input  wire [7:0]   reg_din,
    output wire [7:0]   reg_dout
);

localparam S_REG_IDLE = 0,
           S_REG_WR_ADDR = 1,
           S_REG_WR_DATA = 2,
           S_REG_RD_DATA_TURN = 3,
           S_REG_RD_DATA = 4,
           S_REG_DONE = 5;

localparam S_TX_IDLE = 0,
           S_TX_PID = 1,
           S_TX_DATA = 2,
           S_TX_STP = 3;
           
wire        turnaround;
wire        rx_cmd;

reg         reg_we_reg;
reg  [7:0]  reg_addr_reg;
reg  [7:0]  reg_din_reg;
reg  [7:0]  reg_dout_reg;
reg  [2:0]  reg_state;

wire        tx_strobe;
reg  [2:0]  tx_state;
reg         tx_was_last;
reg  [3:0]  tx_pid;

reg         ulpi_dir_d;
reg         rx_active_reg, rx_error_reg, host_disconnect_reg;
reg [1:0]   line_state_reg;
reg [1:0]   vbus_state_reg;

reg [1:0]   ulpi_stp_reg;
reg [7:0]   ulpi_data_out_reg;

wire        ulpi_tx_strobe;

always @(posedge ulpi_clk)
    ulpi_dir_d <= ulpi_dir;
assign turnaround = ulpi_dir_d != ulpi_dir;

assign rx_cmd = ~turnaround & ulpi_dir & ~ulpi_nxt & (reg_state != S_REG_RD_DATA);

assign ulpi_tx_strobe = ~turnaround & ~ulpi_dir & ulpi_nxt;

always @(posedge ulpi_clk)
    if (ulpi_rst)
        rx_active_reg <= 1'b0;
    else if (turnaround & ~ulpi_dir)
        rx_active_reg <= 1'b0;
    else if (turnaround & ulpi_dir & ulpi_nxt)
        rx_active_reg <= 1'b1;
    else if (rx_cmd)
        rx_active_reg <= ulpi_data_in[4];

always @(posedge ulpi_clk) begin
    if (ulpi_rst) begin
        rx_error_reg <= 1'b0;
        host_disconnect_reg <= 1'b0;
        line_state_reg <= 2'b00;
        vbus_state_reg <= 2'b00;
    end else if (rx_cmd) begin
        rx_error_reg <= (ulpi_data_in[5:4] == 2'b11);
        host_disconnect_reg <= (ulpi_data_in[5:4] == 2'b10);
        line_state_reg <= ulpi_data_in[1:0];
        vbus_state_reg <= ulpi_data_in[3:2];
    end
end

always @(posedge ulpi_clk) begin
    if (ulpi_rst)
        reg_state <= S_REG_IDLE;
    else case (reg_state)
    S_REG_IDLE:
        if (reg_en)
            reg_state <= S_REG_WR_ADDR;
       
    S_REG_WR_ADDR:
        if (~turnaround & ~ulpi_dir & ulpi_nxt & (tx_state == S_TX_IDLE))
            reg_state <= reg_we_reg ? S_REG_WR_DATA : S_REG_RD_DATA_TURN;
        
    S_REG_WR_DATA:
        if (turnaround)
            reg_state <= S_REG_WR_ADDR;
        else if (ulpi_nxt)
            reg_state <= S_REG_DONE;
    
    S_REG_RD_DATA_TURN:
        if (turnaround & ulpi_dir & ulpi_nxt)
            reg_state <= S_REG_WR_ADDR;
        else if (turnaround & ulpi_dir)
            reg_state <= S_REG_RD_DATA;
            
    S_REG_RD_DATA:
        if (rx_active_reg | ulpi_nxt)
            reg_state <= S_REG_WR_ADDR;
        else 
            reg_state <= S_REG_DONE;     
    
    S_REG_DONE:
        reg_state <= S_REG_IDLE;
    
    endcase
end

always @(posedge ulpi_clk) begin
    if ((reg_state == S_REG_IDLE) & reg_en) begin
        reg_we_reg   <= reg_we;
        reg_addr_reg <= reg_addr;
        reg_din_reg  <= reg_din;
    end        
end

always @(posedge ulpi_clk)
    if ((reg_state == S_REG_RD_DATA) & ~rx_active_reg & ~ulpi_nxt)
        reg_dout_reg <= ulpi_data_in;
      
// AXI-Stream TX logic
assign tx_strobe = tx_tvalid & tx_tready;
      
always @(posedge ulpi_clk) begin
    if (ulpi_rst)
        tx_state <= S_TX_IDLE;
    else case (tx_state)
    S_TX_IDLE:
        if (tx_strobe)
            tx_state <= S_TX_PID;
            
    S_TX_PID:
        if (ulpi_tx_strobe)
            tx_state <= tx_was_last ? S_TX_IDLE : S_TX_DATA;
            
    S_TX_DATA:
        if (tx_strobe & tx_tlast)
            tx_state <= S_TX_STP;
        
    S_TX_STP:
        tx_state <= S_TX_IDLE;

    endcase
end 

always @(posedge ulpi_clk) 
    if ((tx_state == S_TX_IDLE) & tx_strobe)
        tx_pid <= tx_tdata[3:0];
        
always @(posedge ulpi_clk) 
    if (tx_strobe)
        tx_was_last <= tx_tlast;
        
assign tx_tready = (tx_state == S_TX_DATA) ? ulpi_tx_strobe : (tx_state == S_TX_IDLE);
        
// AXI-Stream RX logic, pipelined
reg [7:0]   rx_reg1, rx_reg2;
reg         x_reg1_v, rx_reg2_v;
reg         rx_reg2_last;
wire        rx_eop;

assign rx_eop = ~ulpi_dir | ~rx_active_reg;

always @(posedge ulpi_clk)
    if (ulpi_rst | rx_eop)
        x_reg1_v <= 1'b0;
    else if (rx_active_reg & ulpi_nxt)
        x_reg1_v <= 1'b1;

always @(posedge ulpi_clk)
    if (ulpi_rst)
        rx_reg2_v <= 1'b0;
    else if (x_reg1_v & ((rx_active_reg & ulpi_nxt) | rx_eop))
        rx_reg2_v <= 1'b1;
    else if (rx_tvalid & rx_tready)
        rx_reg2_v <= 1'b0;
       
always @(posedge ulpi_clk)
    if (rx_active_reg & ulpi_nxt)
        rx_reg1 <= ulpi_data_in;
 
always @(posedge ulpi_clk)
    if (x_reg1_v & ((rx_active_reg & ulpi_nxt) | rx_eop))
        rx_reg2 <= rx_reg1;
 
always @(posedge ulpi_clk)
    if (ulpi_rst)
        rx_reg2_last <= 1'b0;
    else if (x_reg1_v & rx_eop)
        rx_reg2_last <= 1'b1;
    else if (rx_tvalid & rx_tready)
        rx_reg2_last <= 1'b0;

always @(posedge ulpi_clk)
    if ((tx_state == S_TX_DATA) & tx_strobe & tx_tlast | ((tx_state == S_TX_PID) & tx_was_last & ulpi_tx_strobe))
        ulpi_stp_reg <= 1'b1;
    else if ((reg_state == S_REG_WR_DATA) & ~turnaround)
        ulpi_stp_reg <= 1'b1;
    else if (rx_active_reg & ulpi_nxt & x_reg1_v & rx_reg2_v & ~rx_tready)
        ulpi_stp_reg <= 1'b1;
    else
        ulpi_stp_reg <= 1'b0; 

always @(*) begin
    if (tx_state == S_TX_PID)
        ulpi_data_out_reg <= {4'b0100, tx_pid};
    else if (tx_state == S_TX_DATA)
        ulpi_data_out_reg <= tx_tdata;
    else if (reg_state == S_REG_WR_ADDR)
        ulpi_data_out_reg <= {reg_we_reg ? 2'b10 : 2'b11, reg_addr_reg[5:0]};
    else if (reg_state == S_REG_WR_DATA)
        ulpi_data_out_reg <= reg_din_reg;
    else
        ulpi_data_out_reg <= 8'h00;
end

assign line_state = line_state_reg;
assign rx_active = rx_active_reg;
assign rx_error = rx_error_reg;
assign host_disconnect = host_disconnect_reg;
assign vbus_state = vbus_state_reg;

assign reg_rdy = (reg_state == S_REG_DONE);
assign reg_dout = reg_dout_reg;

assign ulpi_stp = ulpi_stp_reg;

assign ulpi_data_out = ulpi_data_out_reg;

assign rx_tdata = rx_reg2;
assign rx_tlast = rx_reg2_last;
assign rx_tvalid = rx_reg2_v;

endmodule
