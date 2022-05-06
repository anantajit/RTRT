// This module takes 16 clock cycles to realize... increase this if we are running into timing issues

module square(input CLK, input signed [63:0] NUM, output signed [127:0] SQUARE);

// this is just a mini multiplier module... nothing special here.

multiplier SQ_MULTIPLIER(CLK, 128'(signed'(NUM)), 128'(signed'(NUM)), SQUARE);

endmodule