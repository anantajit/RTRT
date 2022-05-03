module  test_ocm
(
		input [15:0] write_address,
		input Clk,
		input [15:0] data_In,
		input we, 
		input [15:0] read_address,
		output logic [15:0] data_Out
);

// mem has width of 16 bits and a total of 64000 addresses
logic [15:0] mem [64000];



always_ff @ (posedge Clk) begin
	if (we)
		mem[write_address] <= data_In;
	data_Out<= mem[read_address];
end

endmodule