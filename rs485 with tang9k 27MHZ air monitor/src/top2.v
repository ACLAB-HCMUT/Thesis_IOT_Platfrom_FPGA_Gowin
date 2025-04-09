module uart_loopback(
  input  wire       Clk,
    input  wire       Rst_n,
    
    // RS485 side (soil sensor)
    input  wire       rs485_rx,   // RX from soil sensor
    output wire       rs485_tx,   // TX to soil sensor
    
    // PC side
    output wire       pc_tx,      // TX to computer (no RX from PC)
    
    // Debug LEDs
    output wire [2:0] led
);

    // ---------------------------
    // Parameters
    // ---------------------------
    parameter DATA_WIDTH = 64;
    parameter MSB_FIRST  = 1;
    
    // Clock frequency (Hz) and delay time (seconds)
    localparam CLK_FREQ      = 27_000_000;
    localparam DELAY_SECONDS = 5;
    localparam DELAY_COUNT   = CLK_FREQ / DELAY_SECONDS;  // 150,000,000 cycles for 3 sec
    localparam DELAY2=CLK_FREQ /100;
    reg[31:0] count1;
    reg [2:0]count2;
    // State machine states
    localparam IDLE       = 3'b000;
    localparam SEND_REQ   = 3'b001;
    localparam WAIT_REPLY = 3'b010;
    localparam SEND_PC    = 3'b011;
    localparam DELAY      = 3'b100;
    localparam DELAY1      = 3'b101;
    

    // ---------------------------
    // Modbus Command
    // ---------------------------
    wire [63:0] cmd_sht20 = {
        8'h01, // Slave ID
        8'h03, // Function code (Read Holding Registers)
        8'h01,
        8'hF5, // Register Address
        8'h00,
        8'h01, // Number of registers
        8'h95,
        8'hC4  // CRC

    
    };
// byte soundRequest[] = {0x15, 0x03, 0x01, 0xF6, 0x00, 0x01, 0x66, 0xD0};
//    byte PressureRequest[] = {0x15, 0x03, 0x01, 0xF9, 0x00, 0x01, 0x56, 0xD3};
//    byte pm2p5Request[] = {0x15, 0x03, 0x01, 0xF7, 0x00, 0x01, 0x37, 0x10};
//    byte PM10Request[] = {0x15, 0x03, 0x01, 0xF8, 0x00, 0x01, 0x07, 0x13};
 //    byte AmbientLight_HighRequest[] = {0x15, 0x03, 0x01, 0xFA, 0x00, 0x01, 0xA6, 0xD3};
//    byte AmbientLightRequest[] = {0x15, 0x03, 0x01, 0xFB, 0x00, 0x01, 0xF7, 0x13};
//    byte TemperatureRequest[] = {0x15, 0x03, 0x01, 0xF5, 0x00, 0x01, 0x96, 0xD0};
//    byte HumidityRequest[] = {0x15, 0x03, 0x01, 0xF4, 0x00, 0x01, 0xC7, 0x10};
//0x15, 0x03, 0x01, 0xF6, 0x00, 0x01, 0x66, 0xD0
    wire [63:0] modbus_cmd = {
        8'h15, // Slave ID
        8'h03, // Function code (Read Holding Registers)
        8'h01,
        8'hF6, // Register Address
        8'h00,
        8'h01, // Number of registers
        8'h66,
        8'hD0  // CRC


    };
      wire [63:0] modbus_cmd1 = {
        8'h01, // Slave ID
        8'h03, // Function code (Read Holding Registers)
        8'h00,
        8'h20, // Register Address
        8'h00,
        8'h01, // Number of registers
        8'h85,
        8'hC0  // CRC


    };
      wire [63:0] modbus_cmd2 = {
        8'h01, // Slave ID
        8'h03, // Function code (Read Holding Registers)
        8'h00,
        8'h1F, // Register Address
        8'h00,
        8'h01, // Number of registers
        8'hB5,
        8'hCC  // CRC


    };
reg[63:0]mod;

    
    // ---------------------------
    // UART #1: Soil Sensor (RS485) Interface
    // ---------------------------
    // TX to sensor
    reg               send_en_sensor;
    wire              Tx_Done_sensor;
    
    uart_data_tx #(
        .DATA_WIDTH(DATA_WIDTH),
        .MSB_FIRST(MSB_FIRST)
    ) u_sensor_tx (
        .Clk       (Clk),
        .Rst_n     (Rst_n),
        .data      (modbus_cmd),
        .send_en   (send_en_sensor),
        .Baud_Set  (3'd0),  // 9600 baud
        .uart_tx   (rs485_tx),
        .Tx_Done   (Tx_Done_sensor),
        .uart_state( /* not used */ )
    );
    
    // RX from sensor
    reg [56-1:0] sensor_data;  // Store received sensor data
    wire [56-1:0] rx_data_sensor;
    wire                  Rx_Done_sensor;
    
    uart_data_rx #(
        .DATA_WIDTH(56),
        .MSB_FIRST(MSB_FIRST)
    ) u_sensor_rx (
        .Clk         (Clk),
        .Rst_n       (Rst_n),
        .uart_rx     (rs485_rx),
        .data        (rx_data_sensor),
        .Rx_Done     (Rx_Done_sensor),
        .timeout_flag(led[0]),  // LED[0] indicates RX timeout
        .Baud_Set    (3'd0)     // 9600 baud
    );
    
    // ---------------------------
    // UART #2: PC Interface (TX only)
    // ---------------------------
    reg               send_en_pc;
    wire              Tx_Done_pc;
    
    // Forward received data to PC
    uart_data_tx #(
        .DATA_WIDTH(56),
        .MSB_FIRST(MSB_FIRST)
    ) u_pc_tx (
        .Clk       (Clk),
        .Rst_n     (Rst_n),
        .data      (sensor_data), // Send stored data
        .send_en   (send_en_pc),
        .Baud_Set  (3'd0),        // 9600 baud
        .uart_tx   (pc_tx),
        .Tx_Done   (Tx_Done_pc),
        .uart_state( /* not used */ )
    );
    
    // ---------------------------
    // State Machine & Delay Counter
    // ---------------------------
    reg [2:0] state;
    reg [31:0] delay_counter;

    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n) begin
            state          <= IDLE;
            send_en_sensor <= 1'b0;
            send_en_pc     <= 1'b0;
            sensor_data    <= 56'd0;
            delay_counter  <= 0;
            count1<=0;
            count2<=0;
        end else begin
            case (state)
                IDLE: begin
//                    if(count2%3==0)begin
//                        mod<=modbus_cmd;
//                    end
//                    else if(count2%3==1)begin
//                        mod<=modbus_cmd1;
//                    end
//                    else begin
//                    mod<=modbus_cmd2;
//                    end

                    send_en_sensor <= 1'b1;  // Start transmission to sensor
                    state          <= SEND_REQ;
                end
                
                SEND_REQ: begin
                      //   count2<=count2+1;
                        send_en_sensor <= 1'b0;
                        state          <=DELAY1;
                    
                end
                DELAY1: begin
                    if (count1 < DELAY2 - 1)
                        count1 <= count1 + 1;
                    else
                        state <= WAIT_REPLY;  // 
                end
                
                WAIT_REPLY: begin
                    if (rx_data_sensor!=0) begin
                        sensor_data    <= rx_data_sensor;  // Store received data
                        send_en_pc     <= 1'b1;  // Trigger PC transmission
                        state          <= SEND_PC;
                    end
                    else begin
                        send_en_pc     <= 1'b1; 
                        state          <= SEND_PC;
                        sensor_data    <= 1;
                    end
                end
                
                SEND_PC: begin
//                       if(count2==3'd3)begin
//                        count2<=0;

//                        end
                        send_en_pc    <= 1'b0;
                        delay_counter <= 0;
                        state         <= DELAY;
                    
                end
                
                DELAY: begin
                    if (delay_counter < DELAY_COUNT - 1)
                        delay_counter <= delay_counter + 1;
                    else
                        state <= IDLE;  // After 3 seconds, restart cycle
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // ---------------------------
    // Debug LED Assignments (optional)
    // ---------------------------
    assign led[1] = Tx_Done_sensor;
    assign led[2] = Tx_Done_pc;
    
endmodule