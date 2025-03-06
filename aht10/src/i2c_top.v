module dht20_top (
    input wire Clk,               // System clock
    input wire Rst_n,             // Reset signal
    output wire i2c_sclk,         // I2C clock
    inout wire i2c_sdat,          // I2C data line
    output wire uart_tx           // UART transmit line
);

    // Parameters for DHT20 device
    localparam DEVICE_ID = 8'h38; // DHT20 I2C device address
    localparam ADDR_MODE = 1'b0;  // Address mode: 0 = 8-bit address

    // FSM state definitions
    localparam IDLE                 = 4'd0;
    localparam POWER_ON_DELAY       = 4'd1;
    localparam CHECK_STATUS         = 4'd2;
    localparam INIT_REGISTERS       = 4'd3;
    localparam TRIGGER_MEASUREMENT  = 4'd4;
    localparam WAIT_FOR_MEASUREMENT = 4'd5;
    localparam READ_DATA            = 4'd6;
    localparam PROCESS_DATA         = 4'd7;
    localparam SEND_DATA            = 4'd8;

    reg [3:0] state; // State register

    // I2C control signals
    reg wrreg_req;
    reg rdreg_req;
    reg [15:0] addr;
    reg [7:0] wrdata;
    wire [7:0] rddata;
    reg [7:0] dht20_data [6:0]; // Buffer to store sensor data
    wire RW_Done;
    wire ack;

    // UART control signals
    reg [15:0] uart_data;
    reg send_en_uart;
    wire Tx_Done;

    // Timing control
    reg [31:0] dly_cnt;
    localparam DLY_CNT_100MS = 32'd5_000_000; // Adjust for 100ms delay
    localparam DLY_CNT_10MS = 32'd500_000;    // Adjust for 10ms delay

    // Temperature and humidity registers
    reg [15:0] temperature;
    reg [15:0] humidity;

    // Instantiate I2C controller
    i2c_control i2c_inst (
        .Clk(Clk),
        .Rst_n(Rst_n),
        .wrreg_req(wrreg_req),
        .rdreg_req(rdreg_req),
        .addr(addr),
        .addr_mode(ADDR_MODE),
        .wrdata(wrdata),
        .rddata(rddata),
        .device_id(DEVICE_ID),
        .RW_Done(RW_Done),
        .ack(ack),
        .dly_cnt_max(DLY_CNT_10MS),
        .i2c_sclk(i2c_sclk),
        .i2c_sdat(i2c_sdat)
    );

    // Instantiate UART module
    uart_data_tx #( 
        .DATA_WIDTH(16), // Sending temperature and humidity
        .MSB_FIRST(1)
    ) uart_inst (
        .Clk(Clk),
        .Rst_n(Rst_n),
        .data(uart_data),
        .send_en(send_en_uart),
        .Baud_Set(3'd0), // 9600 baud rate
        .uart_tx(uart_tx),
        .Tx_Done(Tx_Done),
        .uart_state()
    );

    // FSM for reading and transmitting data from DHT20
    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n) begin
            state <= IDLE;
            wrreg_req <= 1'b0;
            rdreg_req <= 1'b0;
            addr <= 16'd0;
            wrdata <= 8'd0;
            uart_data <= 16'd0;
            send_en_uart <= 1'b0;
            dly_cnt <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    dly_cnt <= 32'd0;
                    state <= POWER_ON_DELAY;
                end

                POWER_ON_DELAY: begin
                    // Initial power-on delay of 100ms
                    if (dly_cnt < DLY_CNT_100MS) begin
                        dly_cnt <= dly_cnt + 1;
                    end else begin
                        dly_cnt <= 32'd0;
                        state <= CHECK_STATUS;
                    end
                end

                CHECK_STATUS: begin
                    // Read status word (0x71)
                    rdreg_req <= 1'b1;
                    addr <= 16'h71;
                    if (RW_Done) begin
                        rdreg_req <= 1'b0;
                        if (rddata == 8'h18) begin
                            state <= TRIGGER_MEASUREMENT;
                        end else begin
                            state <= INIT_REGISTERS;
                        end
                    end
                end

                INIT_REGISTERS: begin
                    // Initialize 0x1B, 0x1C, 0x1E registers sequentially
                    wrreg_req <= 1'b1;
                    case (dly_cnt[1:0])
                        2'd0: begin
                            addr <= 16'h1B;
                            wrdata <= 8'h00;
                        end
                        2'd1: begin
                            addr <= 16'h1C;
                            wrdata <= 8'h00;
                        end
                        2'd2: begin
                            addr <= 16'h1E;
                            wrdata <= 8'h00;
                        end
                    endcase

                    if (RW_Done) begin
                        wrreg_req <= 1'b0;
                        if (dly_cnt[1:0] == 2'd2) begin
                            state <= TRIGGER_MEASUREMENT;
                        end else begin
                            dly_cnt <= dly_cnt + 1;
                        end
                    end
                end

                TRIGGER_MEASUREMENT: begin
                    // Send measurement command (0xAC with parameters 0x33, 0x00)
                    wrreg_req <= 1'b1;
                    addr <= 16'hAC;
                    wrdata <= (dly_cnt[0] == 1'b0) ? 8'h33 : 8'h00;
                    if (RW_Done) begin
                        wrreg_req <= 1'b0;
                        if (dly_cnt[0] == 1'b1) begin
                            state <= WAIT_FOR_MEASUREMENT;
                            dly_cnt <= 32'd0;
                        end else begin
                            dly_cnt <= dly_cnt + 1;
                        end
                    end
                end

                WAIT_FOR_MEASUREMENT: begin
                    // Wait for measurement to complete (poll bit [7] of status)
                    rdreg_req <= 1'b1;
                    addr <= 16'h71;
                    if (RW_Done) begin
                        rdreg_req <= 1'b0;
                        if (!(rddata & 8'h80)) begin
                            state <= READ_DATA;
                        end
                    end
                end

                READ_DATA: begin
                    // Read 6 bytes of measurement data
                    rdreg_req <= 1'b1;
                    addr <= {4'h0, dly_cnt[2:0]}; // Increment address for each byte
                    if (RW_Done) begin
                        rdreg_req <= 1'b0;
                        dht20_data[dly_cnt[2:0]] <= rddata;
                        if (dly_cnt[2:0] == 3'd5) begin
                            state <= PROCESS_DATA;
                        end else begin
                            dly_cnt <= dly_cnt + 1;
                        end
                    end
                end

                PROCESS_DATA: begin
                    // Convert raw data to temperature and humidity values
                    humidity <= (dht20_data[0] << 12) | (dht20_data[1] << 4) | (dht20_data[2] >> 4);
                    temperature <= ((dht20_data[2] & 8'h0F) << 16) | (dht20_data[3] << 8) | dht20_data[4];
                    state <= SEND_DATA;
                end

                SEND_DATA: begin
                    // Transmit data via UART
                    if (!send_en_uart) begin
                        uart_data <= humidity; // First send humidity
                        send_en_uart <= 1'b1;
                    end else if (Tx_Done) begin
                        send_en_uart <= 1'b0;
                        uart_data <= temperature; // Then send temperature
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
