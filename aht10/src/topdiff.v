module dht20_i2c_uart (
    input wire Clk,          // 50 MHz system clock
    input wire Rst_n,        // Active-low reset
    inout wire i2c_sda,      // I2C data line
    output wire i2c_scl,     // I2C clock line
    output wire uart_tx,      // UART transmit line
    output reg led
);

    // Parameters
    parameter CLK_FREQ = 50_000_000;  // 50 MHz
    parameter I2C_FREQ = 400_000;     // 400 kHz I2C clock
    parameter DHT20_ADDR = 8'h38;     // DHT20 I2C address
    parameter WAIT_100MS = CLK_FREQ / 10; // 100 ms delay
    parameter WAIT_80MS = CLK_FREQ / 12;  // ~80 ms delay
    parameter WAIT_5S = CLK_FREQ * 5;     // 5 seconds delay

    // State machine states
    localparam
        IDLE         = 4'd0,
        CHECK_STATUS = 4'd1,
        INIT         = 4'd2,
        WAIT_INIT    = 4'd3,
        TRIGGER      = 4'd4,
        WAIT_MEASURE = 4'd5,
        READ_DATA    = 4'd6,
        SEND_UART    = 4'd7,
        WAIT_5S1      = 4'd8;

    // Internal signals
    reg [3:0] state;
    reg [31:0] timer;
    reg [7:0] wrdata;
    reg wrreq, rdreq;
    wire [47:0] rddata;
    wire RW_Done;
    wire ack;
    reg [31:0] uart_data;
    reg uart_send_en;
    wire uart_tx_done;

    // I2C control instantiation
    i2c_control i2c_ctrl (
        .Clk(Clk),
        .Rst_n(Rst_n),
        .wrreq(wrreq),
        .rdreq(rdreq),
        .wrdata(wrdata),
        .rddata(rddata),
        .device_id(DHT20_ADDR),
        .RW_Done(RW_Done),
        .ack(ack),
        .dly_cnt_max(32'd0), // No additional delay needed here
        .i2c_sclk(i2c_scl),
        .i2c_sdat(i2c_sda)
    );

    // UART transmitter instantiation (assuming your uart_data_tx module)
    uart_data_tx #(
        .DATA_WIDTH(32),
        .MSB_FIRST(1)
    ) uart_tx_inst (
        .Clk(Clk),
        .Rst_n(Rst_n),
        .data(uart_data),
        .send_en(uart_send_en),
        .Baud_Set(3'd0), // Adjust baud rate as needed (e.g., 9600 bps)
        .uart_tx(uart_tx),
        .Tx_Done(uart_tx_done),
        .uart_state()
    );

    // State machine
    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n) begin
            state <= IDLE;
            timer <= 32'd0;
            wrreq <= 1'b0;
            rdreq <= 1'b0;
            wrdata <= 8'd0;
            uart_send_en <= 1'b0;
            uart_data <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    wrreq <= 1'b0;
                    rdreq <= 1'b0;
                    uart_send_en <= 1'b0;
                    if (timer >= WAIT_100MS) begin // Wait 100ms after power-on
                        state <= CHECK_STATUS;
                        timer <= 32'd0;
                    end else begin
                        timer <= timer + 1;
                    end
                end

                CHECK_STATUS: begin
                    wrdata <= 8'h71; // Status check command
                    wrreq <= 1'b1;
                    if (RW_Done) begin
                        wrreq <= 1'b0;
                        if (rddata[7:0] != 8'h18) // If not calibrated
                            state <= INIT;
                        else
                            state <= TRIGGER;
                    end
                end

                INIT: begin
                    case (timer)
                        0: begin
                            wrdata <= 8'hBE; // Initialization command
                            wrreq <= 1'b1;
                        end
                        1: begin
                            wrdata <= 8'h08;
                            wrreq <= 1'b1;
                        end
                        2: begin
                            wrdata <= 8'h00;
                            wrreq <= 1'b1;
                        end
                    endcase
                    if (RW_Done) begin
                        wrreq <= 1'b0;
                        timer <= timer + 1;
                        if (timer == 2)
                            state <= WAIT_INIT;
                    end
                end

                WAIT_INIT: begin
                    if (timer >= WAIT_100MS) begin // Wait 100ms after init
                        timer <= 32'd0;
                        state <= TRIGGER;
                    end else begin
                        timer <= timer + 1;
                    end
                end

                TRIGGER: begin
                    case (timer)
                        0: begin
                            wrdata <= 8'hAC; // Trigger measurement
                            wrreq <= 1'b1;
                        end
                        1: begin
                            wrdata <= 8'h33;
                            wrreq <= 1'b1;
                        end
                        2: begin
                            wrdata <= 8'h00;
                            wrreq <= 1'b1;
                        end
                    endcase
                    if (RW_Done) begin
                        wrreq <= 1'b0;
                        timer <= timer + 1;
                        if (timer == 2)
                            state <= WAIT_MEASURE;
                    end
                end

                WAIT_MEASURE: begin
                    if (timer >= WAIT_80MS) begin // Wait 80ms for measurement
                        timer <= 32'd0;
                        state <= READ_DATA;
                    end else begin
                        timer <= timer + 1;
                    end
                end

                READ_DATA: begin
                    rdreq <= 1'b1;
                    if (RW_Done) begin
                        rdreq <= 1'b0;
                        if (rddata[47] == 1'b0) // Check if measurement is complete (Bit[7] = 0)
                            state <= SEND_UART;
                        else
                            state <= WAIT_MEASURE; // Wait longer if busy
                    end
                end

                SEND_UART: begin
                    // Simplified: Send humidity and temperature as 32-bit data
                    uart_data <= {rddata[39:24], rddata[15:0]}; // Humidity (16 bits), Temp (16 bits)
                    uart_send_en <= 1'b1;
                    if (uart_tx_done) begin
                        uart_send_en <= 1'b0;
                        state <= WAIT_5S;
                    end
                end

                WAIT_5S1: begin
                    if (timer >= WAIT_5S) begin
                        timer <= 32'd0;
                        state <= TRIGGER;
                    end else begin
                        timer <= timer + 1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule