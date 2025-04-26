module i2c_control(
    input Clk,
    input Rst_n,
    input wrreg_req,
    input rdreg_req,
    input reg0,
    input [15:0] addr,
    input addr_mode,
    input [7:0] wrdata,
    output reg [7:0] rddata,
    input [7:0] device_id,
    output reg RW_Done,
    output reg ack,
    input [31:0] dly_cnt_max,
    output i2c_sclk,
    inout i2c_sdat,
    output reg  [19:0] temp,
    output reg  [15:0] hum
);

//    input Clk;
//    input Rst_n;
//    input wrreg_req;
//    input rdreg_req;
//    input [15:0] addr;
//    input addr_mode;
//    input [7:0] wrdata;
//    output reg [7:0] rddata;
//    input [7:0] device_id;
//    output reg RW_Done;
//    output reg ack;
//    input [31:0] dly_cnt_max;
//    output i2c_sclk;
//    inout i2c_sdat;
    reg[7:0]cnt1;
    reg [5:0] Cmd;
    reg [7:0] Tx_DATA;
    wire Trans_Done;
    wire ack_o;
    reg Go;
    wire [15:0] reg_addr;
    
    assign reg_addr = addr_mode ? addr : {addr[7:0], addr[15:8]};

    wire [7:0] Rx_DATA;

    // State machine for I2C control
    localparam 
        WR = 6'b000001,   // Write request
        STA = 6'b000010,  // Start condition
        RD = 6'b000100,   // Read request
        STO = 6'b001000,  // Stop condition
        ACK = 6'b010000,  // Acknowledge condition
        NACK = 6'b100000; // No Acknowledge condition

    i2c_bit_shift i2c_bit_shift_inst(
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

    reg [7:0] state;
    reg [7:0] cnt;
    reg [31:0] dly_cnt;

    localparam
        IDLE = 8'b0000_0001,
        WR_REG = 8'b0000_0010,
        WAIT_WR_DONE = 8'b0000_0100,
        WR_REG_DONE = 8'b0000_1000,
        RD_REG = 8'b0001_0000,
        WAIT_RD_DONE = 8'b0010_0000,
        RD_REG_DONE = 8'b0100_0000,
        WAIT_DLY = 8'b1000_0000,
        WAIT_10=8'b1000_0001,
        WG_REG0=8'b1000_0010,
        WAIT_REG0_DONE=8'b1000_0100,
        REG0_DONE=8'b1000_1000;

    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n) begin
            Cmd <= 6'd0;
            Tx_DATA <= 8'd0;
            Go <= 1'b0;
            rddata <= 0;
            state <= IDLE;
            ack <= 0;
            dly_cnt <= 0;
            cnt <= 0;
            cnt1<=0;
            temp<=0;
            hum<=0;
            
        end else begin
            case (state)
                IDLE: begin
//                        Cmd <= 6'd0;
//            Tx_DATA <= 8'd0;
//            Go <= 1'b0;
//            rddata <= 0;
//            state <= IDLE;
       //     ack <= 0;
       //     dly_cnt <= 0;
       //     cnt <= 0;
            cnt1<=0;
//            temp<=0;
//            hum<=0;


                    cnt <= 0;
                    dly_cnt <= 0;
                    ack <= 0;
                    RW_Done <= 1'b0;   
                    if (reg0)
                        state<= WG_REG0;                 
                    else if (wrreg_req)
                        state <= WR_REG;
                    else if (rdreg_req)
                        state <= RD_REG;
                    else
                        state <= IDLE;
                end
                WG_REG0:begin
                    state<=WAIT_REG0_DONE;
                    case (cnt1)
                    0: write_byte(WR | STA, 8'h88); // Device ID with Write Command
                    1: write_byte(WR|STO, 8'h94);             // Data 1
                endcase
                end
                WAIT_REG0_DONE:begin
                    Go<=1'b0;
                    if(Trans_Done)begin
                        ack<=ack|ack_o;
                        case(cnt1)
                        0:begin cnt1<=1;state=WG_REG0;end
//                        1:begin cnt1<=2;state=WG_REG0;end
                        1:state <= WAIT_10;
                       endcase
                    end
                end
                WAIT_10:begin
//                    rddata <= Rx_DATA;
                    RW_Done<=1'b1;
					state <= IDLE;	
                end

                WR_REG: begin
                    state <= WAIT_WR_DONE;
                    case (cnt)
                        0: write_byte(WR | STA, 8'hEC); // Device ID with Write Command
                        1: write_byte(WR, 8'hF4);             // Data 1
                        2: write_byte(WR|STO, 8'h27);
                                      // After trigger, wait for delay
                        default: ;
                    endcase
                end
                
                WAIT_WR_DONE: begin
                    Go <= 1'b0;
                    if (Trans_Done) begin
                        ack <= ack | ack_o;
                        case (cnt)
                            0: begin cnt <= 1; state <= WR_REG; end
                            1: begin  cnt <= 2;state <= WR_REG; end
//                            2: begin  cnt <= 3;state <= WR_REG; end
                            2: begin state <= WR_REG_DONE;  end
            
                            default: ;
                        endcase
                    end
                end

                WR_REG_DONE: begin
                    temp<=16'd0;
                    hum<=16'd0;
                      RW_Done<=1'b1;
                    state <= IDLE; 
                end

                // WAIT_DLY: begin
                //     if (dly_cnt <= dly_cnt_max) begin
                //         dly_cnt <= dly_cnt + 1;
                //         state <= WAIT_DLY;
                //     end else begin
                //         dly_cnt <= 0;
                //         RW_Done <= 1'b1;
                //         state <= IDLE;
                //     end
                // end

                RD_REG: begin
    state <= WAIT_RD_DONE;
    case (cnt)
//        0: write_byte(WR | STA, 8'h70);   // Device Address with Read Command
        0: write_byte(WR | STA, 8'hEC);   // Read Command with ACK
//      
        1: begin
           write_byte(WR,8'hF7);
           
        end
        2: begin
           write_byte(WR | STA, 8'hED); 
        end
        3: begin
            read_byte(RD | ACK);
             
        end
        4: begin
            read_byte(RD | ACK);
            temp[19:12]<=Rx_DATA;
               
        end
        5: begin
            read_byte(RD | ACK);
            temp[11:4]<=Rx_DATA;
          

        end
        6: begin
            read_byte(RD | ACK);
            temp[3:0]<=Rx_DATA[7:4];
          

        end
        7: begin
            read_byte(RD | ACK);
            hum[15:8]<=Rx_DATA;
          

        end
        8:begin read_byte(RD | NACK | STO);        
           hum[7:0]<=Rx_DATA;
        end
        default: ;
    endcase
end

WAIT_RD_DONE: begin
    Go <= 1'b0;
    if (Trans_Done) begin
         if(cnt<=2)begin
             ack <= ack | ack_o;
         end
        case (cnt)
            0: begin cnt <= 1; state <= RD_REG; end
            1: begin cnt <= 2; state <= RD_REG; end
            2: begin cnt <= 3; state <= RD_REG; end
            3: begin cnt <= 4; state <= RD_REG; end
            4: begin cnt <= 5; state <= RD_REG; end
            5: begin cnt <= 6; state <= RD_REG; end
            6: begin cnt <= 7; state <= RD_REG; end
            7: begin cnt <= 8; state <= RD_REG; end
            8: begin state <= RD_REG_DONE; cnt <= 0; end
            default:;
        endcase
    end
end


                RD_REG_DONE: begin
                    RW_Done<=1'b1;
                    rddata <= Rx_DATA;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    task read_byte;
        input [5:0] Ctrl_Cmd;
        begin
            Cmd <= Ctrl_Cmd;
            Go <= 1'b1;
        end
    endtask

    task write_byte;
        input [5:0] Ctrl_Cmd;
        input [7:0] Wr_Byte_Data;
        begin
            Cmd <= Ctrl_Cmd;
            Tx_DATA <= Wr_Byte_Data;
            Go <= 1'b1;
        end
    endtask

endmodule