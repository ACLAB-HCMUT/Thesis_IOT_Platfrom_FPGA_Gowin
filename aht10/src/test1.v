module i2c_control (
    input wire clk,            // System clock (e.g., 50 MHz)
    input wire rst_n,          // Active-low reset
    input wire [1:0] operation,// 00: write, 01: read 1 byte, 10: read multiple bytes
    input wire start,          // Start the I2C operation
    input wire [7:0] device_id,// I2C device address (e.g., 0x38 for DHT20)
    input wire [7:0] write_data,// Data byte for write operation
    input wire [2:0] num_bytes,// Number of bytes to read (1 to 7)
    output reg [55:0] read_data,// Output for up to 7 bytes (56 bits)
    output reg done,           // Operation complete signal
    output reg ack_status,     // Accumulated ACK status (0 = all ACKs OK)
    output wire i2c_scl,       // I2C clock line
    inout wire i2c_sda         // I2C data line (bidirectional)
);

    // Internal signals
    reg [5:0] cmd;             // Command bits for i2c_bit_shift
    reg [7:0] tx_data;         // Data to transmit
    wire [7:0] rx_data;        // Received data
    wire trans_done;           // Transaction complete from i2c_bit_shift
    wire ack_o;                // ACK signal from i2c_bit_shift (0 = ACK, 1 = NACK)
    reg go;                    // Start signal for i2c_bit_shift

    // State machine states
    localparam 
        IDLE        = 3'd0,
        WRITE_START = 3'd1,
        WRITE_DATA  = 3'd2,
        READ_START  = 3'd3,
        READ_BYTES  = 3'd4,
        DONE        = 3'd5;

    reg [2:0] state;           // Current state
    reg [2:0] byte_count;      // Counts bytes read
    reg [55:0] read_buf;       // Buffer for accumulating read data

    // Instantiate the I2C bit-level module
    i2c_bit_shift i2c_bit_shift_inst (
        .Clk(clk),
        .Rst_n(rst_n),
        .Cmd(cmd),
        .Go(go),
        .Rx_DATA(rx_data),
        .Tx_DATA(tx_data),
        .Trans_Done(trans_done),
        .ack_o(ack_o),
        .i2c_sclk(i2c_scl),
        .i2c_sdat(i2c_sda)
    );

    // State machine and logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cmd <= 6'd0;
            tx_data <= 8'd0;
            go <= 1'b0;
            done <= 1'b0;
            ack_status <= 1'b0;
            read_data <= 56'd0;
            read_buf <= 56'd0;
            byte_count <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    ack_status <= 1'b0;
                    if (start) begin
                        state <= (operation == 2'b00) ? WRITE_START :
                                 (operation == 2'b01 || operation == 2'b10) ? READ_START : IDLE;
                        byte_count <= 3'd0;
                    end
                end

                WRITE_START: begin
                    // Send START condition and device address with write bit (0)
                    cmd <= 6'b000010 | 6'b000001; // STA | WR
                    tx_data <= {device_id, 1'b0};
                    go <= 1'b1;
                    if (trans_done) begin
                        go <= 1'b0;
                        ack_status <= ack_status | ack_o;
                        state <= WRITE_DATA;
                    end
                end

                WRITE_DATA: begin
                    // Send data byte and STOP condition
                    cmd <= 6'b000001 | 6'b001000; // WR | STO
                    tx_data <= write_data;
                    go <= 1'b1;
                    if (trans_done) begin
                        go <= 1'b0;
                        ack_status <= ack_status | ack_o;
                        state <= DONE;
                    end
                end

                READ_START: begin
                    // Send START condition and device address with read bit (1)
                    cmd <= 6'b000010 | 6'b000001; // STA | WR
                    tx_data <= {device_id, 1'b1};
                    go <= 1'b1;
                    if (trans_done) begin
                        go <= 1'b0;
                        ack_status <= ack_status | ack_o;
                        state <= READ_BYTES;
                    end
                end

                READ_BYTES: begin
                    if (byte_count < ((operation == 2'b01) ? 1 : num_bytes) - 1) begin
                        // Read byte with ACK
                        cmd <= 6'b000100 | 6'b010000; // RD | ACK
                    end else begin
                        // Read last byte with NACK and STOP
                        cmd <= 6'b000100 | 6'b100000 | 6'b001000; // RD | NACK | STO
                    end
                    go <= 1'b1;
                    if (trans_done) begin
                        go <= 1'b0;
                        read_buf <= {read_buf[47:0], rx_data}; // Shift in received byte
                        byte_count <= byte_count + 1;
                        if (byte_count == ((operation == 2'b01) ? 0 : num_bytes - 1)) begin
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    read_data <= read_buf;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule