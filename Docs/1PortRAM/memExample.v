module Temp_DRAM (input wire clk, output wire [7:0] LED);

reg [31:0] cnt;
reg [7:0] address_sig;
reg [7:0] data_sig;
wire clock_sig;
wire wren_sig;
reg wren_reg;
reg [23:0] data_cnt;

ram ram_inst (
	.address ( address_sig ),
	.clock ( clock_sig ),
	.data ( data_sig ),
	.wren ( wren_sig ),
	.q ( q_sig )
	);

initial begin
	cnt <= 32'b0;
	address_sig <= 8'b0;
	wren_reg <= 1;
	data_sig <= 8'b0;
	data_cnt <= 24'b111111;
end

assign wren_sig = wren_reg;
assign LED[0] = data_cnt[23];

always @(posedge clk) begin
	cnt <= cnt + 1;
	data_cnt <= data_cnt + 1;
	
	data_sig <= data_sig + 1;
	address_sig <= address_sig + 1;
	
	if (data_sig == 8'b0) begin
		data_sig <= data_sig + 8'b11;
	end
	
	
end


endmodule
