module uart_data_tx(
    Clk,
    Rst_n,
    
    data,
    send_en,   
    Baud_Set,  
    
    uart_tx,  
    Tx_Done,   
    uart_state
);
    
    parameter DATA_WIDTH = 8;  // Data width parameter (default: 8 bits)
    parameter MSB_FIRST = 1;   // Endianness parameter (1 for MSB first, 0 for LSB first)

    input Clk;
    input Rst_n;
    
    input [DATA_WIDTH - 1 : 0] data;  // Input data to be transmitted
    input send_en;  // Send enable signal
    input [2:0] Baud_Set;  // Baud rate selection
    output uart_tx;  // UART transmit output
    output reg Tx_Done;  // Transmission done flag
    output uart_state;  // UART state signal
    
    reg [DATA_WIDTH - 1 : 0] data_r;  // Register to hold data during transmission
    reg [7:0] data_byte;  // Temporary byte for transmission
    reg byte_send_en;  // Enable signal for byte transmission
    wire byte_tx_done;  // Byte transmission done signal
    
    // Instantiate the UART byte transmission module
    uart_byte_tx uart_byte_tx(
        .Clk(Clk),
        .Rst_n(Rst_n),
        .data_byte(data_byte),
        .send_en(byte_send_en),   
        .Baud_Set(Baud_Set),  
        .uart_tx(uart_tx),  
        .Tx_Done(byte_tx_done),   
        .uart_state(uart_state) 
    );
    
    reg [8:0] cnt;  // Counter to track number of bits transmitted
    reg [1:0] state;  // State machine variable
    
    // State machine states
    localparam S0 = 0;  // Idle state
    localparam S1 = 1;  // Load and send byte state
    localparam S2 = 2;  // Wait for byte transmission completion
    localparam S3 = 3;  // Check if all data is sent
    
    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n) begin
            data_byte <= 0;
            byte_send_en <= 0;
            state <= S0;
            cnt <= 0;
        end else begin
            case (state)
                S0: begin  // Idle state
                    data_byte <= 0;
                    cnt <= 0;
                    Tx_Done <= 0;
                    if (send_en) begin
                        state <= S1;
                        data_r <= data;
                    end else begin
                        state <= S0;
                        data_r <= data_r;
                    end
                end
                
                S1: begin  // Load byte to send
                    byte_send_en <= 1;
                    if (MSB_FIRST == 1) begin
                        data_byte <= data_r[DATA_WIDTH-1:DATA_WIDTH - 8];
                        data_r <= data_r << 8;
                    end else begin
                        data_byte <= data_r[7:0];
                        data_r <= data_r >> 8;                    
                    end
                    state <= S2;
                end
                
                S2: begin  // Wait for byte transmission completion
                    byte_send_en <= 0;
                    if (byte_tx_done) begin
                        state <= S3;
                        cnt <= cnt + 9'd8;
                    end else begin
                        state <= S2;
                    end
                end
                
                S3: begin  // Check if all data has been sent
                    if (cnt >= DATA_WIDTH) begin
                        state <= S0;
                        cnt <= 0;
                        Tx_Done <= 1;
                    end else begin
                        state <= S1;
                        Tx_Done <= 0;
                    end
                end
                
                default: state <= S0;
            endcase    
        end
    end

endmodule