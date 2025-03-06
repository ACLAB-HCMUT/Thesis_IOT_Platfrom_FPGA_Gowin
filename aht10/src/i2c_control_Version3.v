module i2c_control(
    input Clk,
    input Rst_n,
    
    output reg [7:0] temperature, // Temperature data
    output reg [15:0] humidity,    // Humidity data
    output reg data_valid,         // Data valid signal
    
    output i2c_sclk,
    inout i2c_sdat
);

    // Internal signals
    reg [5:0] Cmd;
    reg [7:0] Tx_DATA;
    wire Trans_Done;
    wire ack_o;
    reg Go;
    wire [7:0] Rx_DATA;
    
    localparam 
        WR   = 6'b000001,   // Write request
        STA  = 6'b000010,   // Start condition
        RD   = 6'b000100,   // Read request
        STO  = 6'b001000,   // Stop condition
        ACK  = 6'b010000,   // Acknowledge
        NACK = 6'b100000;   // Not Acknowledge
    
    i2c_bit_shift i2c_bit_shift(
        .Clk(Clk),
        .Rst_n(Rst_n),
        .Cmd(Cmd),
        .Go(Go),
        .Rx_DATA(Rx_DATA),
        .Tx_DATA(Tx_DATA),
        .Trans_Done(Trans_Done),
        .ack_o(ack_o),
        .i2c_sclk(i2c_sclk),
        .i2c_sdat(i2c_sdat)
    );
    
    // State machine
    reg[7:0] cnt;
   reg [3:0] state;
    reg [31:0] timer;
    reg [7:0] status_word;
    reg [2:0] byte_cnt;
    reg [7:0] data_buffer [5:0]; // Buffer for 6 bytes of data
    
    localparam
        IDLE           = 4'b0000, // Idle state
        POWER_ON_WAIT  = 4'b0001, // Wait 100 ms after power-on
        READ_STATUS    = 4'b0010, // Read status word
        CHECK_STATUS   = 4'b0011, // Check status word
        TRIGGER_MEAS   = 4'b0100, // Trigger measurement
        WAIT_MEAS      = 4'b0101, // Wait 80 ms for measurement
        POLL_STATUS    = 4'b0110, // Poll status word for completion
        READ_DATA      = 4'b0111, // Read 6 bytes of data
        CALC_DATA      = 4'b1000, // Calculate temperature and humidity
        DONE           = 4'b1001; // Data ready
    
    // Timer for delays
    localparam
        POWER_ON_DELAY = 32'd5_000_000, // 100 ms at 50 MHz
        MEAS_DELAY     = 32'd4_000_000, // 80 ms at 50 MHz
        POLL_DELAY     = 32'd100_000;   // 2 ms at 50 MHz
    
    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n) begin
            state <= IDLE;
            timer <= 0;
            Cmd <= 0;
            Tx_DATA <= 0;
            Go <= 0;
            data_valid <= 0;
            temperature <= 0;
            humidity <= 0;
            byte_cnt <= 0;
            cnt<=0;

        end
        else begin
            case (state)
                IDLE: begin
                    cnt<=0;
                    state <= POWER_ON_WAIT;
                    timer <= 0;
                end
                
                POWER_ON_WAIT: begin
                    if (timer >= POWER_ON_DELAY) begin
                        state <= READ_STATUS;
                        timer <= 0;
                    end
                    else begin
                        timer <= timer + 1;
                    end
                end
                
                READ_STATUS:begin
                    case(cnt)
                    0:write_byte(WR | STA,  8'h70);
                    1:write_byte(WR, reg_addr[15:8]);
					2:write_byte(WR, reg_addr[7:0]);
					3:write_byte(WR | STA,  8'h71 );
					4:read_byte(RD | NACK | STO);
                    endcase
                     if (Trans_Done) begin
                        status_word <= Rx_DATA;
                        temperature<=10;
                        state <= CHECK_STATUS;
                    end
               
            	end
                CHECK_STATUS: begin
                    if ((status_word & 8'h18) == 8'h18) begin
                    
                        state <= TRIGGER_MEAS;
                    end
                    else begin
                        // Initialize registers (not implemented here)
                        state <= IDLE;
                    end
                end
                
                TRIGGER_MEAS: begin
                    write_byte(WR | STA, 8'hAC); // Trigger measurement command
                    
                    if (Trans_Done) begin
                        write_byte(WR, 8'h33); // First parameter
                        if (Trans_Done) begin
                            write_byte(WR | STO, 8'h00); // Second parameter
                            
                            state <= WAIT_MEAS;
                        end
                    end
                end
                
                WAIT_MEAS: begin
                    if (timer >= MEAS_DELAY) begin
                        state <= POLL_STATUS;
                        timer <= 0;
                    end
                    else begin
                        timer <= timer + 1;
                    end
                end
                
                POLL_STATUS: begin
                    write_byte(RD | STA, 8'h71); // Read status word
                    if (Trans_Done) begin
                        if (Rx_DATA[7] == 0) begin
                            state <= READ_DATA;
                        end
                        else begin
                            timer <= 0;
                            if (timer >= POLL_DELAY) begin
//                                state <= POLL_STATUS;
                            state <= READ_DATA;
                            end
                            else begin
                                timer <= timer + 1;
                            end
                        end
                    end
                end
                
                READ_DATA: begin
                    if (byte_cnt < 5) begin
                        
                        read_byte(RD | ACK); // Read with ACK
                    end
                    else begin
                        read_byte(RD | NACK | STO); // Read with NACK and stop
                    end
                    if (Trans_Done) begin
                        data_buffer[byte_cnt] <= Rx_DATA;
                       
                        byte_cnt <= byte_cnt + 1;
                        if (byte_cnt == 5) begin
                            state <= CALC_DATA;
                        end
//                     else begin
//                            state=READ_DATA;
//                         end
                    end
                end
                
                CALC_DATA: begin
                    // Combine bytes to form temperature and humidity
                      //  temperature <= {data_buffer[0], data_buffer[1]};
             //       temperature <= 16'h1111111111111111;
                 //    temperature <= 16'h1111;
                    humidity <= {data_buffer[2], data_buffer[3]};
                    data_valid <= 1;
                    state <= DONE;
                end
                
                DONE: begin
                    data_valid <= 0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    task write_byte;
        input [5:0] Ctrl_Cmd;
        input [7:0] Wr_Byte_Data;
        begin
            Cmd <= Ctrl_Cmd;
            Tx_DATA <= Wr_Byte_Data;
            Go <= 1;
        end
    endtask

    task read_byte;
        input [5:0] Ctrl_Cmd;
        begin
            Cmd <= Ctrl_Cmd;
            Go <= 1;
        end
    endtask

endmodule