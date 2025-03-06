module top_module(
    input Clk,
    input Rst_n,
    
    output i2c_sclk,
    inout i2c_sdat,
    output uart_tx
);

    // Internal signals
    wire [7:0] temperature;
    wire [15:0] humidity;
    wire data_valid;
    
    reg [15:0] uart_data;
    reg send_en_uart;
    wire Tx_Done;
    
    // I2C Control instance
    i2c_control i2c_inst (
        .Clk(Clk),
        .Rst_n(Rst_n),
        .temperature(temperature),
        .humidity(humidity),
        .data_valid(data_valid),
        .i2c_sclk(i2c_sclk),
        .i2c_sdat(i2c_sdat)
        
    );
    
    // UART instance
    uart_data_tx #(
        .DATA_WIDTH(8),
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
    
    // Timer for 5-second interval
    reg [31:0] timer;
    localparam TIMER_MAX = 32'd250_000_000; // 5 seconds at 50 MHz
    
    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n) begin
            timer <= 0;
            send_en_uart <= 0;
            uart_data <= 0;
        end
        else begin
            if (timer >= TIMER_MAX) begin
                timer <= 0;
                if (!send_en_uart) begin
                    uart_data <= temperature; // Send temperature first
                    send_en_uart <= 1;
                end
            end
            else begin
                timer <= timer + 1;
                send_en_uart <= 0;
            end
        end
    end

endmodule