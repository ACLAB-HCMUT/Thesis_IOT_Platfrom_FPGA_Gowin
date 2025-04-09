module uart_byte_tx(
	clk,
	reset_n,
  
	data_byte,
	send_en,   
	baud_set,  
	
	uart_tx,  
	tx_done,   
	uart_state 
);

	input clk ;    // Global clock input for the module, 50MHz
	input reset_n;    // Reset signal input, active low
	input [7:0]data_byte;  // 8-bit data to be transmitted
	input send_en;    // Send enable signal
	input [2:0]baud_set;   // Baud rate selection
	
	output reg uart_tx;    // UART transmission output signal
	output reg tx_done;    // Flag indicating completion of 1-byte data transmission
	output reg uart_state; // Data transmission state
	
	wire reset=~reset_n;
	localparam START_BIT = 1'b0;
	localparam STOP_BIT = 1'b1; 
	
	reg bps_clk;	     // Baud rate clock
	reg [15:0]div_cnt;      // Frequency division counter
	reg [15:0]bps_DR;       // Maximum count value for frequency division
	reg [3:0]bps_cnt;      // Baud rate clock counter
	reg [7:0]data_byte_reg;// Stored data after receiving data_byte
	
	// UART state control: Indicates whether transmission is ongoing
	always@(posedge clk or posedge reset)
	if(reset)
		uart_state <= 1'b0; // Default to idle state
	else if(send_en)
		uart_state <= 1'b1; // Start transmission when send_en is high
	else if(bps_cnt == 4'd11)
		uart_state <= 1'b0; // Return to idle after completing transmission
	else
		uart_state <= uart_state;
	
	// Store the data to be transmitted
	always@(posedge clk or posedge reset)
	if(reset)
		data_byte_reg <= 8'd0; // Clear stored data on reset
	else if(send_en)
		data_byte_reg <= data_byte; // Store the input data when send_en is high
	else
		data_byte_reg <= data_byte_reg;
	
	// Baud rate selection based on baud_set input
	always@(posedge clk or posedge reset)
	if(reset)
		bps_DR <= 16'd2811; // Default baud rate setting
	else begin
		case(baud_set)
			0:bps_DR <= 16'd2811; // Baud rate option 0(27MHZ, so baurate 9600:27*10^6/9600 -1=2811)
			1:bps_DR <= 16'd1405; // Baud rate option 1:19200
			2:bps_DR <= 16'd702; // Baud rate option 2:38400
			3:bps_DR <= 16'd467;  // Baud rate option 3:57600
			4:bps_DR <= 16'd233;  // Baud rate option 4:115200
			default:bps_DR <= 16'd2811; // Default value		
		endcase
	end	
	
	// Frequency division counter for baud rate clock
	always@(posedge clk or posedge reset)
	if(reset)
		div_cnt <= 16'd0; // Reset counter
	else if(uart_state)begin
		if(div_cnt == bps_DR)
			div_cnt <= 16'd0; // Reset when reaching the baud rate threshold
		else
			div_cnt <= div_cnt + 1'b1; // Increment counter
	end
	else
		div_cnt <= 16'd0; // Reset counter when not transmitting
	
	// Generate baud rate clock signal
	always@(posedge clk or posedge reset)
	if(reset)
		bps_clk <= 1'b0; // Reset to low
	else if(div_cnt == 16'd1)
		bps_clk <= 1'b1; // Generate a pulse when the counter reaches 1
	else
		bps_clk <= 1'b0;
	
	// Baud rate counter to track transmission progress
	always@(posedge clk or posedge reset)
	if(reset)	
		bps_cnt <= 4'd0; // Reset counter
	else if(bps_cnt == 4'd11)
		bps_cnt <= 4'd0; // Reset after full transmission cycle
	else if(bps_clk)
		bps_cnt <= bps_cnt + 1'b1; // Increment on baud rate clock pulse
	else
		bps_cnt <= bps_cnt;
		
	// Indicate when transmission is complete
	always@(posedge clk or posedge reset)
	if(reset)
		tx_done <= 1'b0; // Reset to low
	else if(bps_cnt == 4'd11)
		tx_done <= 1'b1; // Set to high when transmission completes
	else
		tx_done <= 1'b0;
		
	// UART transmission logic
	always@(posedge clk or posedge reset)
	if(reset)
		uart_tx <= 1'b1; // Default line state is idle (high)
	else begin
		case(bps_cnt)
			0:uart_tx <= 1'b1; // Idle state
			1:uart_tx <= START_BIT; // Start bit
			2:uart_tx <= data_byte_reg[0]; // Transmit bit 0
			3:uart_tx <= data_byte_reg[1]; // Transmit bit 1
			4:uart_tx <= data_byte_reg[2]; // Transmit bit 2
			5:uart_tx <= data_byte_reg[3]; // Transmit bit 3
			6:uart_tx <= data_byte_reg[4]; // Transmit bit 4
			7:uart_tx <= data_byte_reg[5]; // Transmit bit 5
			8:uart_tx <= data_byte_reg[6]; // Transmit bit 6
			9:uart_tx <= data_byte_reg[7]; // Transmit bit 7
			10:uart_tx <= STOP_BIT; // Stop bit
			default:uart_tx <= 1'b1; // Default to idle
		endcase
	end	

endmodule
