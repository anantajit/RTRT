// This module takes 16 clock cycles to realize... increase this if we are running into timing issues

module multiplier(input CLK, input signed [127:0] NUMA, input signed [127:0] NUMB, output signed [127:0] PRODUCT);

logic signed [127:0] reg_PRODUCT = 0;
assign PRODUCT = reg_PRODUCT;

logic [3:0] slow_clock = 0;

always_ff @ (posedge CLK) begin
	slow_clock <= slow_clock + 1;
end
	
// every 128 cycles... should be plenty
always_ff @ (posedge slow_clock[3]) begin
	reg_PRODUCT <= NUMA * NUMB;
end

endmodule