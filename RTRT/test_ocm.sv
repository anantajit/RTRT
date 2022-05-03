module  test_ocm
(
		input [15:0] ADDRESS,
		input CLK,
		input [15:0] DATA_IN,
		input WE, 
		output logic [15:0] DATAOUT
);

// mem has width of 16 bits and a total of 64000 addresses
logic [15:0] mem [64000];



always_ff @ (posedge CLK) begin
	if (WE)
		mem[ADDRESS] <= DATA_IN;
	DATAOUT<= mem[ADDRESS];
end

endmodule