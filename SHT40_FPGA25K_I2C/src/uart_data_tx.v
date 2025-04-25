
/*
Instantiation Template
---------------------------------------
uart_data_tx
#(
	.DATA_WIDTH(DATA_WIDTH),
	.MSB_FIRST(MSB_FIRST)
)
uart_data_tx(
	.Clk(Clk),
	.Rst_n(Rst_n),
	.data(data),
	.send_en(send_en),   
	.Baud_Set(3'd4),  
	.uart_tx(uart_tx),  
	.Tx_Done(Tx_Done),   
	.uart_state(uart_state)
);
---------------------------------------
During instantiation:
1. Specify the data width for each transmission by modifying the value of DATA_WIDTH.
2. Determine whether to send the high byte or low byte first by modifying the value of MSB_FIRST. Set to 1 to send the high byte first, or 0 to send the low byte first.
3. send_en is a pulse trigger signal; providing a high pulse for one clock cycle triggers a transmission.
4. Baud_Set is the baud rate setting value: 0 (9600), 1 (19200), 2 (38400), 3 (57600), 4 (115200).
5. Upon completion of each transmission (data of the specified width is fully transmitted), Tx_Done generates a high pulse for one clock cycle.
======================================*/


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
	
	parameter DATA_WIDTH = 8;
	parameter MSB_FIRST = 1;

	input Clk;
	input Rst_n;
	
	input [DATA_WIDTH - 1 : 0]data;
	input send_en;
	input [2:0]Baud_Set;
	output uart_tx;
	output reg Tx_Done;
	output uart_state;
	
	reg [DATA_WIDTH - 1 : 0]data_r;

	reg [7:0] data_byte;
	reg byte_send_en;
	wire byte_tx_done;
	
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
	
	reg [8:0]cnt;
	reg [1:0]state;
	
	localparam S0 = 0;	// Wait for transmission request
	localparam S1 = 1;	// Initiate single-byte data transmission
	localparam S2 = 2;	// Wait for single-byte data transmission to complete
	localparam S3 = 3;	// Check if all data transmission is complete
	
	always@(posedge Clk or negedge Rst_n)
	if(!Rst_n)begin
		data_byte <= 0;
		byte_send_en <= 0;
		state <= S0;
		cnt <= 0;
	end
	else begin
		case(state)
			S0: 
				begin
					data_byte <= 0;
					cnt <= 0;
					Tx_Done <= 0;
					if(send_en)begin
						state <= S1;
						data_r <= data;
					end
					else begin
						state <= S0;
						data_r <= data_r;
					end
				end
			
			S1:
				begin
					byte_send_en <= 1;
					if(MSB_FIRST == 1)begin
						data_byte <= data_r[DATA_WIDTH-1:DATA_WIDTH - 8];
						data_r <= data_r << 8;
					end
					else begin
						data_byte <= data_r[7:0];
						data_r <= data_r >> 8;					
					end
					state <= S2;
				end
				
			S2:
				begin
					byte_send_en <= 0;
					if(byte_tx_done)begin
						state <= S3;
						cnt <= cnt + 9'd8;
					end
					else
						state <= S2;
				end
			
			S3:
				if(cnt >= DATA_WIDTH)begin
					state <= S0;
					cnt <= 0;
					Tx_Done <= 1;
				end
				else begin
					state <= S1;
					Tx_Done <= 0;
				end
			default:state <= S0;
		endcase	
	end

endmodule