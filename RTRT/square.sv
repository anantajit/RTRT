// This module takes 8 clock cycles to realize... increase this if we are running into timing issues

module square(input CLK, input[63:0] NUM, output [127:0] SQUARE);

multiplier SQUARER(CLK, NUM, NUM, SQUARE);

endmodule