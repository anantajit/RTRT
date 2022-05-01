module ocm_sim(
	input  [15:0] OCM_ADDR_A, OCM_ADDR_B,
	input MAIN_CLK,
	input [15:0] OCM_DATAIN_A, OCM_DATAIN_B,
	input OCM_WE_A,
	input OCM_WE_B,
	output logic [15:0] OCM_DATAOUT_A, OCM_DATAOUT_B);
	
// Our design has enough registers for 640 * 240... we only need half of this in theory
logic [15:0] LOCAL_REG [153360]; // Registers

logic [15:0] dataout;

always_comb begin
	OCM_DATAOUT_A = dataout;
end
	
always_ff @ (posedge MAIN_CLK) begin

	if(OCM_WE_A) begin
		LOCAL_REG[OCM_ADDR_A] <= OCM_DATAIN_A;
	end
	
	dataout <= 0;

end
	
endmodule