module ocm(
	input [15:0] OCM_ADDR_A, OCM_ADDR_B,
	input MAIN_CLK,
	input [15:0] OCM_DATAIN_A,
	OCM_DATAIN_B,
	input OCM_WE_A,
	OCM_WE_B,
	output [15:0] OCM_DATAOUT_A,
	OCM_DATAOUT_B);

logic [15:0] mem [65536];

	
always_ff @ (posedge MAIN_CLK) begin
	if (OCM_WE_A)
		mem[OCM_ADDR_A] <= OCM_DATAIN_A;
	OCM_DATAOUT_A<= mem[OCM_ADDR_A];
	
	if (OCM_WE_B)
		mem[OCM_ADDR_B] <= OCM_DATAIN_B;
	OCM_DATAOUT_B<= mem[OCM_ADDR_B];
end
	
endmodule