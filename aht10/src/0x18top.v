module topmodule(
    input Clk,                // System clock
    input Rst_n,              // Active low reset
   
    output uart_tx,
    
    output i2c_sclk,          // I2C clock
    inout i2c_sdat            // I2C data line
);

    // I2C Control Signals
    wire [19:0] temp;         // Output temperature data
    wire [19:0] hum;          // Output humidity data
    reg wrreg_req, rdreg_req;
    reg [15:0] addr;
    reg addr_mode;
    reg [7:0] wrdata;
    wire [7:0] rddata;
    reg [7:0] device_id = 8'b01110000; // Device ID for DHT20 in write mode
    wire RW_Done;
    wire ack;

    // UART Control Signals
    reg [39:0] uart_data; // 40 bits: 20 for humidity + 20 for temperature
    reg send_en_uart;
    wire Tx_Done;
    wire uart_state;

    // Internal Registers
    reg [2:0] state;
    reg [2:0] read_cnt;
    reg [31:0] delay_counter;
    reg [39:0] raw_data; // Raw data for temperature and humidity
    reg [19:0] raw_humidity;
    reg [19:0] raw_temperature;

    // Parameters
    localparam IDLE         = 3'b000;
    localparam TRIGGER_MEAS = 3'b001;
    localparam WAIT_MEAS    = 3'b010;
    localparam READ_DATA    = 3'b011;
    localparam PROCESS_DATA = 3'b100;
    localparam SEND_UART    = 3'b101;
    localparam DELAY        = 3'b110; // New state for delay

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
        .device_id(8'b01110000),
        .RW_Done(RW_Done),
        .ack(ack),
        .dly_cnt_max(32'd50000000),
        .i2c_sclk(i2c_sclk),
        .i2c_sdat(i2c_sdat),
        .temp(temp),
        .hum(hum)
    );

    // Instantiate UART Data Transmitter
    uart_data_tx #(
        .DATA_WIDTH(40), // 20-bit humidity + 20-bit temperature
        .MSB_FIRST(0)
    ) uart_inst (
        .Clk(Clk),
        .Rst_n(Rst_n),  
        .data(uart_data),
        .send_en(send_en_uart),
        .Baud_Set(3'd0), // 9600 baud rate
        .uart_tx(uart_tx),
        .Tx_Done(Tx_Done),
        .uart_state(uart_state)
    );

    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n) begin
            state <= IDLE;
            wrreg_req <= 0;
            rdreg_req <= 0;
            addr <= 0;
            addr_mode <= 0;
            wrdata <= 0;
            raw_data <= 0;
            raw_humidity <= 0;
            raw_temperature <= 0;
            uart_data <= 40'h0;
            send_en_uart <= 0;
            delay_counter <= 0;
            read_cnt <= 0;
        end else begin
            case (state)
            IDLE:begin
           
    
            state<=READ_DATA;
            end
//                IDLE: begin
//                    wrreg_req <= 1;
//                    rdreg_req <= 0;
//                    addr <= 0;
//                    addr_mode <= 0;
//                    if (RW_Done) begin
//                        wrreg_req <= 0;
//                        state <= WAIT_MEAS;
//                        read_cnt <= 0;
//                    end
//                end

//                WAIT_MEAS: begin
//                    if (delay_counter < 32'd4_000_000) begin
//                        delay_counter <= delay_counter + 1;
//                    end else begin
//                        delay_counter <= 0;
//                        state <= READ_DATA;
//                        rdreg_req <= 1;
//                    end
//                end

              READ_DATA: begin
                 
                   if (!rdreg_req) begin
                       rdreg_req <= 1;
                       addr <= 0;

                   end  
                   else  if (RW_Done) begin
                       raw_humidity <= hum;
                       raw_temperature <= temp;
                       rdreg_req <= 0;
                        
                       state <= PROCESS_DATA;
                       read_cnt <= 0;
                   end
               end

               PROCESS_DATA: begin
                   uart_data <= {hum,temp}; // Combine humidity and temperature
                   state <= DELAY;
               end

    

                DELAY: begin
                    if (delay_counter < 32'd250_000_000) begin // 5 seconds delay (assuming 50 MHz clock)
                        delay_counter <= delay_counter + 1;
                         send_en_uart <= 0;
                    end else begin
                        delay_counter <= 0;
                         send_en_uart <= 1;
                         if(Tx_Done)begin
                        state <= IDLE; // Go back to IDLE state after delay
                        send_en_uart<=0;
                         end
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule