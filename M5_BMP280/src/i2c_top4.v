module topmodule(
    input Clk,                // System clock
    input Rst_n,              // Active low reset
   
    output uart_tx,
    
    output i2c_sclk,          // I2C clock
    inout i2c_sdat            // I2C data line
);

    // I2C Control Signals
    wire [19:0] temp;         // Output temperature data
    wire [15:0] hum;          // Output humidity data
    reg wrreg_req, rdreg_req,reg0;
    reg [15:0] addr;
    reg addr_mode;
    reg [7:0] wrdata;
    wire [7:0] rddata;
    reg [7:0] device_id = 8'b01110000; // Device ID for DHT20 in write mode
    wire RW_Done;
    wire ack;

    // UART Control Signals
    reg [35:0] uart_data; // 40 bits: 20 for humidity + 20 for temperature
    reg send_en_uart;
    wire Tx_Done;
    wire uart_state;

    // Internal Registers
    reg [3:0] state;
    reg [2:0] read_cnt;
    reg [31:0]delay1;
    reg [31:0] delay_counter;
     reg [31:0] delay_counter1;

    reg [35:0] raw_data; // Raw data for temperature and humidity
    reg [15:0] raw_humidity;
    reg [19:0] raw_temperature;

    // Parameters
    localparam IDLE         = 4'b0000;
    localparam TRIGGER_MEAS = 4'b0001;
    localparam WAIT_MEAS    = 4'b0010;
    localparam READ_DATA    = 4'b0011;
    localparam PROCESS_DATA = 4'b0100;
    localparam SEND_UART    = 4'b0101;
    localparam DELAY        = 4'b0110; // New state for delay
    localparam IDLE0        = 4'b0111;
    localparam WAIT_0       = 4'b1000;
    localparam  WAIT_UART_DONE=4'b1001;
 // Instantiate I2C Controller
    i2c_control i2c_inst (
        .Clk(Clk),
        .Rst_n(Rst_n),
        .wrreg_req(wrreg_req),
        .rdreg_req(rdreg_req),
        .reg0(reg0),
        .addr(addr),
        .addr_mode(addr_mode),
        .wrdata(wrdata),
        .rddata(rddata),
        .device_id(8'b01110000),
        .RW_Done(RW_Done),
        .ack(ack),
        .dly_cnt_max(32'd5000000),
        .i2c_sclk(i2c_sclk),
        .i2c_sdat(i2c_sdat),
        .temp(temp),
        .hum(hum)
    );

    // Instantiate UART Data Transmitter
    uart_data_tx #(
        .DATA_WIDTH(36), // 20-bit humidity + 20-bit temperature
        .MSB_FIRST(1)
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
            state <= IDLE0;
            wrreg_req <= 0;
            rdreg_req <= 0;
            reg0=0;
            addr <= 0;
            addr_mode <= 0;
            wrdata <= 0;
            raw_data <= 0;
            raw_humidity <= 0;
            raw_temperature <= 0;
            uart_data <= 0;
            send_en_uart <= 0;
            delay_counter <= 0;
            delay_counter1<=0;
            delay1<=0;
            read_cnt <= 0;
        end else begin
            case (state)
                IDLE0:begin
                   // reg0<=1;
//                     wrreg_req <= 0;
//                     addr <= 0;
//                    addr_mode <= 0;
//                    if (RW_Done) begin
//                        reg0 <= 0;
//                        state <= WAIT_0;
//                        
//                    end

//                end
//                wrreg_req <= 0;
//            rdreg_req <= 0;
//            reg0=0;
//            addr <= 0;
//            addr_mode <= 0;
//            wrdata <= 0;
//            raw_data <= 0;
//            raw_humidity <= 0;
//            raw_temperature <= 0;
//            uart_data <= 0;
//            send_en_uart <= 0;
//            delay_counter <= 0;
//            delay_counter1<=0;
//            delay1<=0;
//            read_cnt <= 0;
//                reg0<=1;
                 wrreg_req <= 0;
                state<=WAIT_0;
                end
                WAIT_0:begin
                     if (delay1 < 32'd500000) begin
                        delay1 <= delay1 + 1;
                    end else begin
                        delay1 <= 0;
                        wrreg_req <= 1;
                        state <= IDLE;
                    end
                end
                IDLE: begin
                    // wrreg_req <= 1;
                   // rdreg_req <= 0;
                      
                     raw_humidity <= 0;
                     raw_temperature <= 0;
                    addr <= 0;
                    addr_mode <= 0;
                    if (RW_Done) begin
                        wrreg_req <= 0;
                        state <= WAIT_MEAS;
                       
//                          if (!send_en_uart) begin
//                        send_en_uart <= 1;
//                    end else if (Tx_Done) begin
//                        send_en_uart <= 0;
//                        state <= READ_DATA; // Transition to delay state
//                    end
                    end
                 
            
                end

                WAIT_MEAS: begin
                    if (delay_counter < 32'd500_000) begin
                        
                        delay_counter <= delay_counter + 1;
                    end else begin
                        
                        delay_counter <= 0;
                        state <= READ_DATA;
                        rdreg_req <= 1;
                    end
                    
                 
                end

                READ_DATA: begin
                    addr <= 0;
                    if (RW_Done) begin
                        raw_humidity <= hum;
                        raw_temperature <= temp;
                        rdreg_req <= 0;
                       // 
                        state <= PROCESS_DATA;
                        read_cnt <= 0;
                    end
                    
                end

                PROCESS_DATA: begin
               //     if(uart_data!={temp,hum})begin
                    uart_data <= {raw_temperature, raw_humidity}; // Combine humidity and temperature
                    state <= SEND_UART;
                  //  end
//                    else begin
//                    uart_data<=1'd1;
//                    end
                end

                 SEND_UART: begin
                      send_en_uart <= 1;  // Trigger UART
                    state <= WAIT_UART_DONE;
                 end
                

                WAIT_UART_DONE: begin
                send_en_uart <= 0;  // Deassert trigger after 1 cycle
            if (Tx_Done) begin
                    state <= DELAY;
                end
end

                // DELAY: begin
                //     if (delay_counter < 32'd250_000_000) begin // 5 seconds delay (assuming 50 MHz clock)
                //         delay_counter <= delay_counter + 1;
                //     end else begin
                //         delay_counter <= 0;
                //         state <= IDLE; // Go back to IDLE state after delay
                //     end
                // end
                    
                    DELAY: begin
                    if (delay_counter1 < 32'd250_000_000) begin // 5 seconds delay (assuming 50 MHz clock)
                        delay_counter1 <= delay_counter1 + 1;
                     //    send_en_uart <= 0;
                    end else begin
                        delay_counter1 <= 0;
                      //   send_en_uart <= 1;
                   //      if(Tx_Done)begin
                        state <= IDLE0; // Go back to IDLE state after delay
                //       send_en_uart<=0;
                    //     end
                    end
                end
                default: state <= IDLE0;
            endcase
        end
    end
endmodule