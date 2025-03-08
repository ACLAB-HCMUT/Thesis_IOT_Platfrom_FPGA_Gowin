//////////////////////////////////////////////////////////////////////////////////
// UART Byte Receiver Module
// Receives a byte of data via UART, synchronizes the input, samples the data
// based on the selected baud rate, and outputs the received byte along with a
// reception completion signal.
//////////////////////////////////////////////////////////////////////////////////

module uart_byte_rx(
    Clk,
    Rst_n,
    baud_set,
    uart_rx,
    data_byte,
    Rx_Done
);

    input Clk;   // System clock
    input Rst_n; // Active-low reset

    input [2:0]baud_set; // Baud rate selection
    input uart_rx;   // UART serial data input
    
    output [7:0]data_byte; // Received data byte
    output Rx_Done;   // Reception complete flag
    
    reg [7:0]data_byte;
    reg Rx_Done;
    reg uart_rx_sync1;   
    reg uart_rx_sync2;  

    reg uart_rx_reg1;    
    reg uart_rx_reg2;    

    reg [15:0]bps_DR;    // Baud rate divider value
    reg [15:0]div_cnt;   // Baud rate clock divider counter
    reg bps_clk;    // Baud rate clock enable signal
    reg [7:0] bps_cnt;   // Bit position counter
    reg uart_state;  // UART receiver state machine

    wire uart_rx_nedge;  // Detects a falling edge on the RX line (start bit)

    reg [2:0]START_BIT;
    reg [2:0]STOP_BIT;
    reg [2:0]data_byte_pre [7:0]; // Array to store sampled bits

    // Synchronize UART input to avoid metastability
    always@(posedge Clk or negedge Rst_n)
    if(!Rst_n) begin
        uart_rx_sync1 <= 1'b0;
        uart_rx_sync2 <= 1'b0;    
    end
    else begin
        uart_rx_sync1 <= uart_rx;
        uart_rx_sync2 <= uart_rx_sync1;    
    end
    
    // Detect falling edge for start bit detection
    always@(posedge Clk or negedge Rst_n)
    if(!Rst_n) begin
        uart_rx_reg1 <= 1'b0;
        uart_rx_reg2 <= 1'b0;    
    end
    else begin
        uart_rx_reg1 <= uart_rx_sync2;
        uart_rx_reg2 <= uart_rx_reg1;    
    end
    
    assign uart_rx_nedge = !uart_rx_reg1 & uart_rx_reg2;
    
    // Baud rate divider setup
    always@(posedge Clk or negedge Rst_n)
    if(!Rst_n)
        bps_DR <= 16'd324;
    else begin
        case(baud_set)
            0: bps_DR <= 16'd324;
            1: bps_DR <= 16'd162;
            2: bps_DR <= 16'd80;
            3: bps_DR <= 16'd53;
            4: bps_DR <= 16'd26;
            default: bps_DR <= 16'd324;            
        endcase
    end
    
    // Clock divider for baud rate generation
    always@(posedge Clk or negedge Rst_n)
    if(!Rst_n)
        div_cnt <= 16'd0;
    else if(uart_state) begin
        if(div_cnt == bps_DR)
            div_cnt <= 16'd0;
        else
            div_cnt <= div_cnt + 1'b1;
    end
    else
        div_cnt <= 16'd0;
        
    // Generate baud clock enable signal
    always@(posedge Clk or negedge Rst_n)
    if(!Rst_n)
        bps_clk <= 1'b0;
    else if(div_cnt == 16'd1)
        bps_clk <= 1'b1;
    else
        bps_clk <= 1'b0;
    
    // Count bit positions during reception
    always@(posedge Clk or negedge Rst_n)
    if(!Rst_n)    
        bps_cnt <= 8'd0;
    else if(bps_cnt == 8'd159 || (bps_cnt == 8'd12 && (START_BIT > 2)))
        bps_cnt <= 8'd0;
    else if(bps_clk)
        bps_cnt <= bps_cnt + 1'b1;
    
    // Indicate end of byte reception
    always@(posedge Clk or negedge Rst_n)
    if(!Rst_n)
        Rx_Done <= 1'b0;
    else if(bps_cnt == 8'd159)
        Rx_Done <= 1'b1;
    else
        Rx_Done <= 1'b0;        
        
    // Sample received bits
    always@(posedge Clk or negedge Rst_n)
    if(!Rst_n) begin
        START_BIT <= 3'd0;
        STOP_BIT <= 3'd0;
        data_byte_pre[0] <= 3'd0;
        data_byte_pre[1] <= 3'd0;
        data_byte_pre[2] <= 3'd0;
        data_byte_pre[3] <= 3'd0;
        data_byte_pre[4] <= 3'd0;
        data_byte_pre[5] <= 3'd0;
        data_byte_pre[6] <= 3'd0;
        data_byte_pre[7] <= 3'd0;
    end
    else if(bps_clk) begin
        case(bps_cnt)
            6,7,8,9,10,11: START_BIT <= START_BIT + uart_rx_sync2;
            22,23,24,25,26,27: data_byte_pre[0] <= data_byte_pre[0] + uart_rx_sync2;
            38,39,40,41,42,43: data_byte_pre[1] <= data_byte_pre[1] + uart_rx_sync2;
            54,55,56,57,58,59: data_byte_pre[2] <= data_byte_pre[2] + uart_rx_sync2;
            70,71,72,73,74,75: data_byte_pre[3] <= data_byte_pre[3] + uart_rx_sync2;
            86,87,88,89,90,91: data_byte_pre[4] <= data_byte_pre[4] + uart_rx_sync2;
            102,103,104,105,106,107: data_byte_pre[5] <= data_byte_pre[5] + uart_rx_sync2;
            118,119,120,121,122,123: data_byte_pre[6] <= data_byte_pre[6] + uart_rx_sync2;
            134,135,136,137,138,139: data_byte_pre[7] <= data_byte_pre[7] + uart_rx_sync2;
            150,151,152,153,154,155: STOP_BIT <= STOP_BIT + uart_rx_sync2;
        endcase
    end

    // Store final received byte
    always@(posedge Clk or negedge Rst_n)
    if(!Rst_n)
        data_byte <= 8'd0;
    else if(bps_cnt == 8'd159) begin
        data_byte[0] <= data_byte_pre[0][2];
        data_byte[1] <= data_byte_pre[1][2];
        data_byte[2] <= data_byte_pre[2][2];
        data_byte[3] <= data_byte_pre[3][2];
        data_byte[4] <= data_byte_pre[4][2];
        data_byte[5] <= data_byte_pre[5][2];
        data_byte[6] <= data_byte_pre[6][2];
        data_byte[7] <= data_byte_pre[7][2];
    end    
    
    // UART receiver state management
    always@(posedge Clk or negedge Rst_n)
    if(!Rst_n)
        uart_state <= 1'b0;
    else if(uart_rx_nedge)
        uart_state <= 1'b1;
    else if(Rx_Done || (bps_cnt == 8'd12 && (START_BIT > 2)) || (bps_cnt == 8'd155 && (STOP_BIT < 3)))
        uart_state <= 1'b0;
    
endmodule
