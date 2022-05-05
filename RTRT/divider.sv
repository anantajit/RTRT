// This module takes 64 clock cycles to realize
// TODO: replace numerator with 64 bit

module divider(input CLK, input[63:0] numerator, input [63:0] denominator, output [127:0] quotient);

logic [7:0] slow_clock = 0;

always_ff @ (posedge CLK) begin
	slow_clock <= slow_clock + 1;
end
	
// every 128 cycles... should be plenty
always_ff @ (posedge slow_clock[6]) begin
	quotient <= numerator / denominator;
end

endmodule