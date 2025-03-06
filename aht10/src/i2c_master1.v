module i2c_control (
    input Clk,
    input Rst_n,
    
    input wrreq,             // Write request
    input rdreq,             // Read request
    input [7:0] wrdata,      // Data to write
    output reg [47:0] rddata,// 6 bytes of read data (48 bits)
    input [7:0] device_id,   // I2C device address (e.g., 0x38 for DHT20)
    output reg RW_Done,      // Operation complete signal
    output reg ack,          // Accumulated ACK status
    
    input [31:0] dly_cnt_max,// Delay counter max value
    
    output i2c_sclk,         // I2C clock
    inout i2c_sdat           // I2C data
);

    // Internal signals
    reg [5:0] Cmd;
    reg [7:0] Tx_DATA;
    wire [7:0] Rx_DATA;
    wire Trans_Done;
    wire ack_o;
    reg Go;

    // Command definitions
    localparam 
        WR   = 6'b000001, // Write request
        STA  = 6'b000010, // Start condition
        RD   = 6'b000100, // Read request
        STO  = 6'b001000, // Stop condition
        ACK  = 6'b010000, // Acknowledge
        NACK = 6'b100000; // Not acknowledge

    // Instantiate i2c_bit_shift
    i2c_bit_shift i2c_bit_shift_inst (
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

    // State machine states
    reg [7:0] state;
    localparam
        IDLE         = 8'b00000001,
        WR_START     = 8'b00000010,
        WAIT_WR_DONE = 8'b00000100,
        RD_START     = 8'b00001000,
        WAIT_RD_DONE = 8'b00010000,
        DONE         = 8'b00100000,
        WAIT_DLY     = 8'b01000000;

    reg [3:0] cnt;           // Counter for transaction steps
    reg [31:0] dly_cnt;      // Delay counter
    reg [47:0] rddata_buf;   // Buffer for 6-byte read data

    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n) begin
            Cmd <= 6'd0;
            Tx_DATA <= 8'd0;
            Go <= 1'b0;
            rddata <= 48'd0;
            rddata_buf <= 48'd0;
            state <= IDLE;
            ack <= 1'b0;
            dly_cnt <= 32'd0;
            cnt <= 4'd0;
            RW_Done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    cnt <= 4'd0;
                    dly_cnt <= 32'd0;
                    ack <= 1'b0;
                    RW_Done <= 1'b0;
                    if (wrreq)
                        state <= WR_START;
                    else if (rdreq)
                        state <= RD_START;
                    else
                        state <= IDLE;
                end

                WR_START: begin
                    state <= WAIT_WR_DONE;
                    case (cnt)
                        0: write_byte(STA | WR, device_id);        // Start + device address (write)
                        1: write_byte(WR, wrdata);                 // Write command/data
                        2: write_byte(STO, 8'h00);                 // Stop condition
                        default: ;
                    endcase
                end

                WAIT_WR_DONE: begin
                    Go <= 1'b0;
                    if (Trans_Done) begin
                        ack <= ack | ack_o;
                        cnt <= cnt + 1;
                        if (cnt < 2)
                            state <= WR_START;
                        else
                            state <= DONE;
                    end
                end

                RD_START: begin
                    state <= WAIT_RD_DONE;
                    case (cnt)
                        0: write_byte(STA | WR, device_id | 8'd1); // Start + device address (read)
                        1,2,3,4: read_byte(RD | ACK);              // Read 5 bytes with ACK
                        5: read_byte(RD | NACK | STO);             // Read last byte with NACK + Stop
                        default: ;
                    endcase
                end

                WAIT_RD_DONE: begin
                    Go <= 1'b0;
                    if (Trans_Done) begin
                        if (cnt == 0)
                            ack <= ack | ack_o;
                        else if (cnt >= 1 && cnt <= 5)
                            rddata_buf[47 - (cnt-1)*8 -: 8] <= Rx_DATA; // Store each byte
                        cnt <= cnt + 1;
                        if (cnt < 5)
                            state <= RD_START;
                        else
                            state <= DONE;
                    end
                end

                DONE: begin
                    rddata <= rddata_buf; // Output the 6-byte data
                    state <= WAIT_DLY;
                end

                WAIT_DLY: begin
                    if (dly_cnt < dly_cnt_max) begin
                        dly_cnt <= dly_cnt + 1;
                        state <= WAIT_DLY;
                    end else begin
                        dly_cnt <= 32'd0;
                        RW_Done <= 1'b1;
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Task to initiate a write operation
    task write_byte;
        input [5:0] Ctrl_Cmd;
        input [7:0] Wr_Byte_Data;
        begin
            Cmd <= Ctrl_Cmd;
            Tx_DATA <= Wr_Byte_Data;
            Go <= 1'b1;
        end
    endtask

    // Task to initiate a read operation
    task read_byte;
        input [5:0] Ctrl_Cmd;
        begin
            Cmd <= Ctrl_Cmd;
            Go <= 1'b1;
        end
    endtask

endmodule