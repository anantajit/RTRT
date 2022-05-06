// This module takes 64 clock cycles to realize
// TODO: replace numerator with 64 bit

module divider(input CLK, input signed [63:0] numerator, input signed [63:0] denominator, output signed [127:0] quotient);

logic signed [63:0] reg_quotient;
assign quotient = 128'(signed'(reg_quotient));

logic [7:0] slow_clock = 0;

always_ff @ (posedge CLK) begin
	slow_clock <= slow_clock + 1;
end
	
// every 128 cycles... should be plenty
always_ff @ (posedge slow_clock[6]) begin
	reg_quotient <= numerator / denominator;
end

endmodule