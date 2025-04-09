`timescale 1ns / 1ps

module iic_slave_design (
    // External I2C signals
    input                   iic_scl,
    inout                   iic_sda,
    input[39:0]             dht20_data,
    input [7:0]             slave_addr,
    output [7:0]            IOout
);

wire iic_sda_shadow    /* synthesis keep = 1 */;
wire start_or_stop /* synthesis keep = 1 */;
assign iic_sda_shadow = (~iic_scl | start_or_stop) ? iic_sda : iic_sda_shadow;
assign start_or_stop = ~iic_scl ? 1'b0 : (iic_sda ^ iic_sda_shadow);

reg incycle;
reg [5:0] bitcnt;  // Expanded to 6-bit to handle 40-bit response
wire bit_DATA = (bitcnt < 8);  // First 8 bits are DATA
wire bit_ACK = (bitcnt == 8);  // 9th bit is ACK
wire bit_RESPONSE = (bitcnt > 8); // Bits after 8 are for response
reg data_phase;

always @(negedge iic_scl or posedge start_or_stop)begin
    if(start_or_stop) incycle <= 1'b0; 
    else if(~iic_sda) incycle <= 1'b1;
end

always @(negedge iic_scl or negedge incycle)begin 
    if(~incycle) begin
        bitcnt <= 6'd7;  // Start at bit 7
        data_phase <= 0;
    end
    else begin
        if(bit_ACK) begin
            bitcnt <= 6'd7;
            data_phase <= 1;
        end
        else begin
            bitcnt <= bitcnt - 6'd1;
        end
    end 
end

wire adr_phase = ~data_phase;
reg adr_match, op_read, got_ACK;
reg iic_sdar; 
reg [7:0] mem;
reg [39:0] response_buffer; // 40-bit response buffer
reg transmit_40bit; // Flag to indicate response transmission
wire op_write = ~op_read;

always @(posedge iic_scl)begin 
    iic_sdar <= iic_sda;
end

always @(negedge iic_scl or negedge incycle)begin 
    if(~incycle) begin
        got_ACK <= 0;
        adr_match <= 1;
        op_read <= 0;
        transmit_40bit <= 0; // Reset flag
    end 
    else begin
        if(adr_phase & bitcnt==7 & iic_sdar!=slave_addr[6]) adr_match<=0;
        if(adr_phase & bitcnt==6 & iic_sdar!=slave_addr[5]) adr_match<=0;
        if(adr_phase & bitcnt==5 & iic_sdar!=slave_addr[4]) adr_match<=0;
        if(adr_phase & bitcnt==4 & iic_sdar!=slave_addr[3]) adr_match<=0;
        if(adr_phase & bitcnt==3 & iic_sdar!=slave_addr[2]) adr_match<=0;
        if(adr_phase & bitcnt==2 & iic_sdar!=slave_addr[1]) adr_match<=0;
        if(adr_phase & bitcnt==1 & iic_sdar!=slave_addr[0]) adr_match<=0;
        if(adr_phase & bitcnt==0) op_read <= iic_sdar;
        
        if(bit_ACK) got_ACK <= ~iic_sdar;

        if(adr_match & bit_DATA & data_phase & op_write) begin
            mem[bitcnt[2:0]] <= iic_sdar;  // Store received data
        end

        // If received data is 1, prepare for 40-bit transmission
        if(mem == 8'h01) begin
            transmit_40bit <= 1;
            response_buffer <= dht20_data; // Example 40-bit response
            bitcnt <= 6'd39;  // Set counter to 39 for 40-bit transmission
        end
    end
end

// Outputting response buffer during transmission phase
wire mem_bit_low = ~response_buffer[bitcnt[5:0]];
wire iic_sda_assert_low = adr_match & bit_RESPONSE & transmit_40bit & mem_bit_low & got_ACK;
wire iic_sda_assert_ACK = adr_match & bit_ACK & (adr_phase | op_write);
wire iic_sda_low = iic_sda_assert_low | iic_sda_assert_ACK;
assign iic_sda = iic_sda_low ? 1'b0 : 1'bz;

assign IOout = mem;

endmodule 
