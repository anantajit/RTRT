module testbench();

timeunit 10ns;	// Half clock cycle at 50MHz
			// This is the amount of time represented by #1 
timeprecision 1ns;

ray_sphere_intersection(
	input CLK, 
	input ENABLE, 
	input [8:0] sphere[4], 
	input [8:0] p0[3], 
	input [8:0] p1[3], 
	input BOUNDED, 
	input [3:0] THRESHOLD, 
	
	output READY, 
	output COLLIDE,
	output [8:0] pint0[3], 
	output [8:0] pint1[3]);

// These signals are internal because the processor will be 
// instantiated as a submodule in testbench.
logic CLK;

// Toggle the clock
// #1 means wait for a delay of 1 timeunit
always begin : CLOCK_GENERATION
#1 CLK = ~CLK;
end

initial begin: CLOCK_INITIALIZATION
    CLK = 0;
end 

// Testing begins here
// The initial block is not synthesizable
// Everything happens sequentially inside an initial block
// as in a software program
initial begin: TEST_VECTORS


end



endmodule
