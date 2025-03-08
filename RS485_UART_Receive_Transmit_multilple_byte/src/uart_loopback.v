module uart_loopback(
   input Clk,
    input Rst_n,
    input uart_rx,
    
    output [2:0]led,
    output uart_tx,
     output reg DE,      // Driver Enable for RS485
     output reg RE           // Receiver Enable for RS485
 );
 
    parameter DATA_WIDTH = 64;//(64bit=8byte)
	parameter MSB_FIRST = 1;
	reg [DATA_WIDTH-1:0] data_byte_tx;   // Data byte to be transmitted
        wire [DATA_WIDTH-1:0] data_byte_rx;  // Data byte received from UART    
 //   wire [DATA_WIDTH-1:0]rx_data;
        wire Rx_Done;
 //   wire [7:0]data_byte;
        reg send_en;              // Enable signal for transmission
        wire tx_done;             // TX done signal from uart_byte_tx
                 // RX done signal from uart_byte_rx
        reg rx_done_reg;          // Register to latch rx_done signal
        always @(posedge Clk or negedge Rst_n) begin
            if (!Rst_n)
                rx_done_reg <= 1'b0;
            else
                rx_done_reg <=Rx_Done; // Capture rx_done on rising edge
        end

        // Logic to handle sending data after reception
        always @(posedge Clk or negedge Rst_n) begin
            if (!Rst_n) begin
                data_byte_tx <= 8'd0;
                send_en <= 1'b0;
            end else if (Rx_Done && !rx_done_reg) begin
                // If new data is received, load it into data_byte_tx
                data_byte_tx <= data_byte_rx;
                send_en <= 1'b1; // Enable transmission
            end else begin
                send_en <= 1'b0; // Disable transmission if no new data
            end
        end
  uart_data_rx 
    #(
		.DATA_WIDTH(DATA_WIDTH),
		.MSB_FIRST(MSB_FIRST)		
	)
	uart_data_rx(
        .Clk(Clk),
        .Rst_n(Rst_n),
        .uart_rx(uart_rx),
        
        .data(data_byte_rx),
        .Rx_Done(Rx_Done),
        .timeout_flag(led[0]),
        
        .Baud_Set(3'd0)
     );

    uart_data_tx 
    #(
		.DATA_WIDTH(DATA_WIDTH),
		.MSB_FIRST(MSB_FIRST)
	)uart_data_tx(
        .Clk(Clk),
        .Rst_n(Rst_n),
      
        .data(data_byte_tx),
        .send_en(send_en),   
        .Baud_Set(3'd0),  
        
        .uart_tx(uart_tx),  
        .Tx_Done(led[1]),   
        .uart_state(led[2])
    );
  // RS485 direction control logic
        always @(posedge Clk or negedge Rst_n) begin
            if (!Rst_n) begin
                DE <= 1'b0;  // Start with receiver enabled (default state)
                RE <= 1'b1;  // Receiver enabled by default
            end else begin
                if (send_en) begin
                    // Enable driver when sending
                    DE <= 1'b1;  // Driver enable
                    RE <= 1'b0;  // Receiver disable
                end else begin
                    // Enable receiver when not sending
                    DE <= 1'b0;  // Driver disable
                    RE <= 1'b1;  // Receiver enabled
                end
            end
        end
    
endmodule
