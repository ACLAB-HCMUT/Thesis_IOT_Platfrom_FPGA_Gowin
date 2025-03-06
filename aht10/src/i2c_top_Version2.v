module topmodule_dht20 (
    input Clk,
    input Rst_n,
    output i2c_sclk,
    inout i2c_sdat,
    output uart_tx
);

    // I2C Control Signals
    reg wrreg_req, rdreg_req;
    reg [15:0] addr;
    reg addr_mode;
    reg [7:0] wrdata;
    wire [47:0] rddata; // 48-bit data for humidity and temperature
    reg [7:0] device_id = 8'b01110000; // Device ID for DHT20 in write mode
    wire RW_Done;
    wire ack;

    // UART Control Signals
    reg [39:0] uart_data; // 20 bits for humidity + 20 bits for temperature
    reg send_en_uart;
    wire Tx_Done;

    // Internal Registers
    reg [2:0] state;
    reg [31:0] delay_counter;  // Used for various timing delays
    reg [1:0] wr_cnt; // Counter for the write sequence
    reg [19:0] raw_humidity;
    reg [19:0] raw_temperature;

    // Parameters for state machine
    localparam IDLE         = 3'b000;
    localparam WRITE_SEQ    = 3'b001;
    localparam WAIT_MEAS    = 3'b010; // Wait for 80ms measurement time
    localparam READ_DATA    = 3'b011;
    localparam SEND_UART    = 3'b100;
    localparam WAIT_AFTER_TX = 3'b101; // Wait for 5 seconds after UART transmission

    // Instantiate I2C Controller
    i2c_control i2c_inst (
        .Clk(Clk),
        .Rst_n(Rst_n),
        .wrreg_req(wrreg_req),
        .rdreg_req(rdreg_req),
        .addr(addr),
        .addr_mode(addr_mode),
        .wrdata(wrdata),
        .rddata(rddata),
        .device_id(device_id),
        .RW_Done(RW_Done),
        .ack(ack),
        .dly_cnt_max(32'd5000000),  // 100,000 for I2C delay max, adjust as needed
        .i2c_sclk(i2c_sclk),
        .i2c_sdat(i2c_sdat)
    );

    // Instantiate UART Data Transmitter
    uart_data_tx #(
        .DATA_WIDTH(40), // 20-bit humidity + 20-bit temperature
        .MSB_FIRST(1)
    ) uart_inst (
        .Clk(Clk),
        .Rst_n(Rst_n),
        .data(uart_data),
        .send_en(send_en_uart),
        .Baud_Set(3'd0), // 9600 baud rate
        .uart_tx(uart_tx),
        .Tx_Done(Tx_Done)
    );

    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n) begin
            state <= IDLE;
            wrreg_req <= 0;
            rdreg_req <= 0;
            addr <= 0;
            addr_mode <= 0;
            wrdata <= 0;
            raw_humidity <= 0;
            raw_temperature <= 0;
            uart_data <= 0;
            send_en_uart <= 0;
            delay_counter <= 0;
            wr_cnt <= 0;
        end else begin
            case (state)
                IDLE: begin
                    // Initialize for the write sequence to start measurement
                    wrreg_req <= 1;
                    addr <= 0; // Address to write
                    addr_mode <= 0; // Address mode (standard)
                    wr_cnt <= 0;
                    state <= WRITE_SEQ;
                end

                WRITE_SEQ: begin
                    // Send the three bytes required for measurement
                    case (wr_cnt)
                        0: wrdata <= 8'hAC; // First byte (measurement command)
                        1: wrdata <= 8'h33; // Second byte
                        2: wrdata <= 8'h00; // Third byte
                    endcase

                    if (RW_Done) begin
                        wr_cnt <= wr_cnt + 1;
                        if (wr_cnt == 2) begin
                            wrreg_req <= 0;
                            state <= WAIT_MEAS; // Wait 80 ms for the measurement
                        end
                    end
                end

                WAIT_MEAS: begin
                    // Wait for 80ms after starting the measurement
                    if (delay_counter < 32'd4_000_000) begin // Assuming 50MHz clock, adjust accordingly
                        delay_counter <= delay_counter + 1;
                    end else begin
                        delay_counter <= 0;
                        state <= READ_DATA; // Once the measurement is ready, proceed to read data
                        rdreg_req <= 1;  // Start the read sequence
                    end
                end

                READ_DATA: begin
                    // Read the 48-bit data from DHT20 after the measurement
                    addr <= 0; // Address to read
                    if (RW_Done) begin
                        rdreg_req <= 0;
                        // Separate humidity and temperature from rddata
                        raw_humidity <= rddata[47:28]; // High 20 bits
                        raw_temperature <= rddata[27:8]; // Middle 20 bits
                        uart_data <= {raw_humidity, raw_temperature}; // Combine for UART
                        state <= SEND_UART;
                    end
                end

                SEND_UART: begin
                    // Transmit data over UART
                    if (!send_en_uart) begin
                        send_en_uart <= 1;
                    end else if (Tx_Done) begin
                        send_en_uart <= 0;
                        state <= WAIT_AFTER_TX; // Wait for 5 seconds after transmitting data
                    end
                end

                WAIT_AFTER_TX: begin
                    // Wait 5 seconds before starting the next cycle (IDLE state)
                    if (delay_counter < 32'd250_000_000) begin // 5 seconds delay at 50 MHz clock
                        delay_counter <= delay_counter + 1;
                    end else begin
                        delay_counter <= 0;
                        state <= IDLE; // Reset to IDLE to start the process again
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
