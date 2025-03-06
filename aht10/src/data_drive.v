module data_drive (
    input			wire						clk,
    input			wire						rst_n,
    input			wire						din_vld,
    input			wire		[ 19:0 ]		temp_data,
    input			wire		[ 19:0 ]		hum_data,
    output			wire						tx_data
);


reg								send_flag			;
reg			[ 19:0 ]			temp_data_r			;
reg			[ 19:0 ]			hum_data_r			;
reg			[ 7:0 ]			    dout_r			;
wire		[ 15:0 ]			tmep			;
wire		[ 15:0 ]			hum			;
reg			[ 5:0 ]			    cnt			;
wire							add_cnt			;
wire							end_cnt			;
wire							rdreq			;
wire							wrreq			;
wire							empty			;
wire							full			;
wire							tx_done			;
wire		[ 7:0 ]				q		;
assign rdreq = tx_done && ~empty;
assign wrreq = ~full && send_flag && cnt > 0;


//串口模块
uart_tx u_uart_tx(
    .clk       ( clk       ),
    .rst_n     ( rst_n     ),
    .tx_enable ( rdreq      ),
    .data_in   ( q   ),
    .tx_bps    ( 115200    ),
    .data      ( tx_data      ),
    .tx_done   ( tx_done   )
);

//用于缓存通过串口发送的数据
fifo	tx_fifo_inst (
	.aclr ( ~rst_n ),
	.clock ( clk ),
	.data ( dout_r ),
	.rdreq ( rdreq ),
	.wrreq ( wrreq ),
	.empty ( empty ),
	.full ( full ),
	.q ( q ),
	.usedw ( usedw_sig )
	);

//温湿度数据寄存
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        temp_data_r <= 0;
        hum_data_r <= 0;
    end
    else if(din_vld) begin
        temp_data_r <= (((temp_data*2000)>>12) - (500)); //扩大10倍
        hum_data_r <= ((hum_data *1000) >> 12);
    end
end

//数据处理标志
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        send_flag <= 0;
    end
    else if(din_vld) begin
        send_flag <= 1;
    end
    else if(end_cnt) begin
        send_flag <= 0;
    end
end

//计数器
always @( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) begin
        cnt <= 0;
    end
    else if ( add_cnt ) begin
        if ( end_cnt ) begin
            cnt <= 0;
        end
        else begin
            cnt <= cnt + 1;
        end
    end
end
assign add_cnt = send_flag;
assign end_cnt = add_cnt && cnt == 22;
// CE C2 B6 C8 CA AA B6 C8
//根据计数器发送不同数据
always @(posedge clk or negedge rst_n) begin
    case (cnt)
        1 : dout_r <= 8'hce; // 温度
        2 : dout_r <= 8'hc2;
        3 : dout_r <= 8'hb6;
        4 : dout_r <= 8'hc8;
        5 : dout_r <= 8'h3a; // :
        6 : dout_r <= (temp_data_r / 100 % 10 )+48;//十位
        7 : dout_r <= (temp_data_r / 10 % 10  )+48;//个位
        8 : dout_r <= 8'h2e;//.
        9 : dout_r <= (temp_data_r % 10  )+48;
        10 : dout_r <= 8'ha1; //℃
        11 : dout_r <= 8'he6;
        12: dout_r <= 9;     //tab
        13: dout_r <= 8'hca; //湿度
        14: dout_r <= 8'haa;
        15: dout_r <= 8'hb6;
        16: dout_r <= 8'hc8;
        17: dout_r <= 8'h3a;
        18: dout_r <= (hum_data_r / 100 % 10 )+48;
        19: dout_r <= (hum_data_r / 10 % 10 )+48;
        20: dout_r <= 8'h2e;
        21: dout_r <= (hum_data_r % 10  )+48;
        22: dout_r <= 8'h25;//%
        default: dout_r <= 0;
    endcase
end
endmodule //data_drive