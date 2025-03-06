module aht10_top (
    input			wire						clk,
    input			wire						rst_n,
    inout			wire						sda,
    output			wire						scl,
    output			wire						uart_txd
);

 
wire             slave_ack       ;
wire             i2c_sda_i       ; 
wire             i2c_sda_o       ; 
wire             i2c_sda_oe      ; 
assign sda = i2c_sda_oe?i2c_sda_o:1'bz;
assign i2c_sda_i = sda;


wire                        req             ; 
wire        [ 3:0 ]         cmd             ; 
wire		[ 7:0 ]			din			    ;
wire		[ 7:0 ]			dout			;
i2c_intf u_i2c_intf(
    .clk        ( clk        ),
    .rst_n      ( rst_n      ),
    .req        ( req        ),
    .cmd        ( cmd        ),
    .din        ( din        ),
    .dout       ( dout       ),
    .done       ( done       ),
    .slave_ack  ( slave_ack  ),
    .i2c_scl    ( scl    ),
    .i2c_sda_i  ( i2c_sda_i  ),
    .i2c_sda_o  ( i2c_sda_o  ),
    .i2c_sda_oe  ( i2c_sda_oe  )
);

wire		[ 19:0 ]			hum_data			;
wire		[ 19:0 ]			temp_data			;

i2c_master u_i2c_master(
    .clk       ( clk       ),
    .rst_n     ( rst_n     ),
    .req       ( req       ),
    .cmd       ( cmd       ),
    .data      ( din      ),
    .done      ( done      ),
    .rd_data   ( dout   ),
    .hum_data  ( hum_data  ),
    .temp_data  ( temp_data  ),
    .dout_vld (din_vld)
);


data_drive u_data_drive(
    .clk       ( clk       ),
    .rst_n     ( rst_n     ),
    .din_vld   ( din_vld   ),
    .temp_data ( temp_data ),
    .hum_data  ( hum_data  ),
    .tx_data   ( uart_txd    )
);


endmodule //aht10_top