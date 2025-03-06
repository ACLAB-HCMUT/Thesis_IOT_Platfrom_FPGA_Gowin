module dht20_i2c_uart (
    input wire Clk,            // System clock (e.g., 50 MHz)
    input wire Rst_n,          // Active-low reset
    inout wire i2c_sda,        // I2C data line
    output wire i2c_scl,       // I2C clock line
    output wire uart_tx        // UART transmit line
);

    // Parameters
    parameter CLK_FREQ = 50_000_000;       // 50 MHz clock
    parameter WAIT_100MS = CLK_FREQ / 10;  // 100 ms delay
    parameter WAIT_80MS = CLK_FREQ / 12;   // ~80 ms delay
    parameter WAIT_5S = CLK_FREQ * 5;      // 5 seconds delay
    parameter DHT20_ADDR = 8'h38;          // DHT20 I2C address

    // State machine states
    localparam
        IDLE          = 4'd0,
        POWER_ON_DELAY= 4'd1,
        CHECK_STATUS  = 4'd2,
        TRIGGER_MEAS  = 4'd3,
        WAIT_MEASURE  = 4'd4,
        READ_DATA     = 4'd5,
        SEND_UART     = 4'd6,
        WAIT_5S1       = 4'd7;

    // Internal signals
    reg [3:0] state;           // Current state
    reg [31:0] timer;          // Timer for delays
    reg [1:0] operation;       // I2C operation mode
    reg start_i2c;             // Start I2C operation
    reg [7:0] write_data;      // Data to write to DHT20
    reg [2:0] num_bytes;       // Number of bytes to read
    wire [55:0] read_data;     // Data read from I2C
    wire i2c_done;             // I2C operation done
    wire ack_status;           // I2C ACK status
    reg [55:0] sensor_data;    // Stored sensor data for UART
    reg uart_send_en;          // Enable UART transmission
    wire uart_tx_done;         // UART transmission complete

    // Instantiate I2C control module
    i2c_control i2c_ctrl (
        .clk(Clk),
        .rst_n(Rst_n),
        .operation(operation),
        .start(start_i2c),
        .device_id(DHT20_ADDR),
        .write_data(write_data),
        .num_bytes(num_bytes),
        .read_data(read_data),
        .done(i2c_done),
        .ack_status(ack_status),
        .i2c_scl(i2c_scl),
        .i2c_sda(i2c_sda)
    );

    // Instantiate UART transmitter (assumed 56-bit data width)
    uart_data_tx #(
        .DATA_WIDTH(56),  // 7 bytes
        .MSB_FIRST(1)     // Send MSB first
    ) uart_tx_inst (
        .Clk(Clk),
        .Rst_n(Rst_n),
        .data(sensor_data),
        .send_en(uart_send_en),
        .Baud_Set(3'd4),  // e.g., 115200 baud, adjust as needed
        .uart_tx(uart_tx),
        .Tx_Done(uart_tx_done),
        .uart_state()     // Unused
    );

    // State machine
    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n) begin
            state <= IDLE;
            timer <= 32'd0;
            start_i2c <= 1'b0;
            operation <= 2'b00;
            write_data <= 8'd0;
            num_bytes <= 3'd0;
            uart_send_en <= 1'b0;
            sensor_data <= 56'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (timer >= WAIT_100MS) begin
                        state <= CHECK_STATUS;
                        timer <= 32'd0;
                    end else begin
                        timer <= timer + 1;
                    end
                end

                CHECK_STATUS: begin
                    operation <= 2'b01;  // Read 1 byte
                    start_i2c <= 1'b1;
                    if (i2c_done) begin
                        start_i2c <= 1'b0;
                        if (read_data[7:0] == 8'h18)  // Status OK
                            state <= TRIGGER_MEAS;
                        else
                            state <= IDLE;  // Retry or error handling
                    end
                end

                TRIGGER_MEAS: begin
                    operation <= 2'b00;  // Write
                    write_data <= 8'hAC; // DHT20 measurement trigger command
                    start_i2c <= 1'b1;
                    if (i2c_done) begin
                        start_i2c <= 1'b0;
                        state <= WAIT_MEASURE;
                    end
                end

                WAIT_MEASURE: begin
                    if (timer >= WAIT_80MS) begin
                        state <= READ_DATA;
                        timer <= 32'd0;
                    end else begin
                        timer <= timer + 1;
                    end
                end

                READ_DATA: begin
                    operation <= 2'b10;  // Read multiple bytes
                    num_bytes <= 3'd7;   // Read 7 bytes
                    start_i2c <= 1'b1;
                    if (i2c_done) begin
                        start_i2c <= 1'b0;
                        sensor_data <= read_data;
                        state <= SEND_UART;
                    end
                end

                SEND_UART: begin
                    uart_send_en <= 1'b1;
                    if (uart_tx_done) begin
                        uart_send_en <= 1'b0;
                        state <= WAIT_5S;
                    end
                end

                WAIT_5S1: begin
                    if (timer >= WAIT_5S) begin
                        timer <= 32'd0;
                        state <= TRIGGER_MEAS;
                    end else begin
                        timer <= timer + 1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule