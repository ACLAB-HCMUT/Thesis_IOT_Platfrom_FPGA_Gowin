`include "param.v"

module i2c_master (
    input               clk     ,
    input               rst_n   ,
    
    input               din_vld ,
    output              req     ,
    output      [3:0]   cmd     ,
    output      [7:0]   data    ,
    input               done    , //传输完成标志
    input       [7:0]   rd_data ,
    output		[ 19:0 ]	hum_data			,//湿度
    output      [ 19:0 ]	temp_data			,//温度	
    output				    dout_vld			
    );


//状态机参数
    localparam      START =      7'b000_0001    , //等待40ms
                    INIT =       7'b000_0010    , //初始化
                    CHECK_INIT = 7'b000_0100    , //检测是否初始化完成
                    IDLE =       7'b000_1000    , //空闲
                    TRIGGER =    7'b001_0000    , //触发测量
                    WAIT =       7'b010_0000    , //等待80ms测量完成
                    READ =       7'b100_0000    ; //读取温湿度

    parameter	DELAY_40MS = 200_0000;//40ms
    parameter	DELAY_80MS = 400_0000;//80ms
    parameter	DELAY_500MS = 2500_0000;//0.5s

//信号定义
    reg     [7:0]   state_c         ;
    reg     [7:0]   state_n         ;

    reg     [2:0]   cnt_byte        ;//数据传输 字节计数器
    wire            add_cnt_byte    ;
    wire            end_cnt_byte    ;

    reg             tx_req          ;//请求
    reg     [3:0]   tx_cmd          ;
    reg     [7:0]   tx_data         ;
    reg			[ 47:0 ]			read_data			;

    
    reg			[ 27:0 ]			cnt			;//40ms 80ms计数器
    wire							add_cnt			;
    wire							end_cnt			;

    reg							    finish_init			;
    wire							start_2_init		;//等待40ms后进入初始化
    wire							init_2_check		;//检查是否初始化成功
    wire							check_2_idle			;//初始化完成进入空闲
    wire							check_2_init			;//初始化失败重新初始化
    wire							idle_2_trigger			;//发送读取温湿度指令
    wire							trigger_2_wait			;//等待转换完成
    wire							wait_2_read			;//读取温湿度
    wire							read_2_idle			;//读取完毕进入空闲

    assign start_2_init = state_c == START && (end_cnt);
    assign init_2_check = state_c == INIT && (end_cnt_byte);
    assign check_2_idle = state_c == CHECK_INIT && (finish_init);
    assign check_2_init = state_c == CHECK_INIT && (~finish_init);
    assign idle_2_trigger = state_c == IDLE && (end_cnt);
    assign trigger_2_wait = state_c == TRIGGER && (end_cnt_byte);
    assign wait_2_read = state_c == WAIT && (end_cnt);
    assign read_2_idle = state_c == READ && (end_cnt_byte);

//状态机设计
    always @(posedge clk or negedge rst_n) begin 
        if (rst_n==0) begin
            state_c <= START ;
        end
        else begin
            state_c <= state_n;
       end
    end
//状态跳转   
    always @(*) begin 
        case(state_c)  
            START :begin
                if(start_2_init)
                    state_n = INIT ;
                else 
                    state_n = state_c ;
            end
            INIT :begin
                if(init_2_check)
                    state_n = IDLE ;
                else 
                    state_n = state_c ;
            end
            CHECK_INIT :begin
                if(check_2_idle)
                    state_n = IDLE ;
                else if(check_2_init) begin
                    state_n = INIT;
                end
                else 
                    state_n = state_c ;
            end
            IDLE :begin
                if(idle_2_trigger)
                    state_n = TRIGGER ;
                else 
                    state_n = state_c ;
            end
            TRIGGER :begin
                if(trigger_2_wait)
                    state_n = WAIT ;
                else 
                    state_n = state_c ;
            end
            WAIT :begin
                if(wait_2_read)
                    state_n = READ ;
                else 
                    state_n = state_c ;
            end
            READ :begin
                if(read_2_idle)
                    state_n = IDLE ;
                else 
                    state_n = state_c ;
            end

            default : state_n = START ;
        endcase
    end

    reg			[ 24:0 ]			delay			;
    
//延时数据寄存器
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            delay <= DELAY_40MS;
        end
        else if(state_c == START) begin
            delay <= DELAY_40MS;
        end
        else if(state_c == WAIT) begin
            delay <= DELAY_80MS;
        end
        else if(state_c == IDLE) begin
            delay <= DELAY_500MS;
        end
    end

//延时计数器
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
        else begin
            cnt <= 0;
        end
    end
    assign add_cnt = state_c == START || state_c == WAIT || state_c == IDLE;
    assign end_cnt = cnt == delay - 1 && add_cnt;

//字节计数器
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            cnt_byte <= 0;
        end
        else if(add_cnt_byte) begin
            if(end_cnt_byte) begin
                cnt_byte <= 0;
            end
            else
                cnt_byte <= cnt_byte + 1;
        end
    end
    assign add_cnt_byte = (state_c == INIT || state_c == CHECK_INIT ||state_c == TRIGGER || state_c == READ) && done;
    assign end_cnt_byte = cnt_byte == (state_c == READ?6:3) && add_cnt_byte;

/*必须使用组合,接口模块done信号延后一个时钟,req等数据需提前
根据当前状态控制i2c接口发送数据*/
    always  @(*)begin
        case (state_c)
            INIT : 
                case(cnt_byte)
                    0           :TX(1'b1,{`CMD_START | `CMD_WRITE},{`I2C_ADR,1'b0});//发起始位、地址
                    1           :TX(1'b1, `CMD_WRITE ,`CMD_INIT);  //发数据,结束位
                    2           :TX(1'b1,`CMD_WRITE ,8'b000_1000);  //发数据,结束位
                    3           :TX(1'b1,{`CMD_WRITE | `CMD_STOP} ,8'b0000_0000);  //发数据,结束位
                    default     :TX(1'b0,tx_cmd,tx_data);
                endcase 
            CHECK_INIT:
                case(cnt_byte)
                    0           :TX(1'b1,{`CMD_START | `CMD_WRITE},{`I2C_ADR,1'b0});//发起始位、写控制字
                    1           :TX(1'b1,`CMD_WRITE ,`CMD_CHECK);  //发数据
                    2           :TX(1'b1,{`CMD_START | `CMD_WRITE},{`I2C_ADR,1'b1});//发起始位、读控制字
                    3           :TX(1'b1,{`CMD_READ | `CMD_STOP},0);  //最后一个字节时 读数据、发停止位
                    default     :TX(1'b0,tx_cmd,tx_data);
                endcase
            TRIGGER: 
                case(cnt_byte)
                    0           :TX(1'b1,{`CMD_START | `CMD_WRITE},{`I2C_ADR,1'b0});//发起始位、写控制字
                    1           :TX(1'b1,`CMD_WRITE ,`CMD_TRIGGER);  //发数据
                    2           :TX(1'b1,`CMD_WRITE ,`DATA_0);  //发数据
                    3           :TX(1'b1,{`CMD_WRITE | `CMD_STOP},`DATA_1);  //最后一个字节时、发停止位
                    default     :TX(1'b0,tx_cmd,tx_data);
                endcase    
            READ :            
                case(cnt_byte)
                    0           :TX(1'b1,{`CMD_START | `CMD_WRITE},{`I2C_ADR,1'b1});//发起始位、写控制字
                    1           :TX(1'b1,`CMD_READ ,0);  //读数据
                    2           :TX(1'b1,`CMD_READ ,0);  //读数据
                    3           :TX(1'b1,`CMD_READ ,0);  //读数据
                    4           :TX(1'b1,`CMD_READ ,0);  //读数据
                    5           :TX(1'b1,`CMD_READ ,0);  //读数据
                    6           :TX(1'b1,{`CMD_READ | `CMD_STOP},0);
                    default     :TX(1'b0,tx_cmd,tx_data);
                endcase
            default: TX(1'b0,0,0);
        endcase
    end
//初始化完成标志
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            finish_init <= 0;
        end
        else if(state_c == CHECK_INIT && done && rd_data[3]) begin
            finish_init <= 1;
        end
    end
//i2c 接口返回数据
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            read_data <= 0;
        end
        else if(state_c == READ && cnt_byte >0 && done) begin
            read_data <= {read_data[39:0],rd_data};
        end
    end
//用task发送请求、命令、数据（地址+数据）
    task TX;   
        input                   req     ;
        input       [3:0]       command ;
        input       [7:0]       data    ;
        begin 
            tx_req  = req;
            tx_cmd  = command;
            tx_data = data;
        end 
    endtask   
//输出

    assign req     = tx_req ; 
    assign cmd     = tx_cmd ; 
    assign data    = tx_data; 
    assign hum_data = read_data[39:20];
    assign temp_data = read_data[19:0];
    assign dout_vld = read_2_idle;



endmodule //camera_config_ctrl