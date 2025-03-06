//i2c时钟参数
`define  SCL_PERIOD  250
`define  SCL_HALF    125
`define  LOW_HLAF    65 
`define  HIGH_HALF   190

//i2c命令参数
`define CMD_START   4'b0001
`define CMD_WRITE   4'b0010
`define CMD_READ    4'b0100
`define CMD_STOP    4'b1000


`define I2C_ADR 7'b011_1000 
`define CMD_INIT 8'b1110_0001 
`define CMD_CHECK 8'b0111_0001
`define CMD_TRIGGER 8'b1010_1100
`define DATA_0 8'b0011_0011
`define DATA_1 8'b0000_0000

//串口参数定义

`define  BAUD_9600   5208
`define  BAUD_19200  2604
`define  BAUD_38400  1302
`define  BAUD_115200 434

`define STOP_BIT  1'b1
`define START_BIT 1'b0


