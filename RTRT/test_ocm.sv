module  test_ocm
(
		input [18:0] ADDRESS,
		input CLK,
		input [18:0] DATA_IN,
		input WE, 
		output logic [3:0] DATAOUT
);

// mem has width of 16 bits and a total of 64000 addresses
logic [3:0] mem [307200]; // each pixel is stored in 4 bit address



always_ff @ (posedge CLK) begin
	if (WE)
		mem[ADDRESS] <= DATA_IN;
	DATAOUT<= mem[ADDRESS];
end

endmodule