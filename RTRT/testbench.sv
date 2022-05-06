module testbench();

timeunit 10ns;	// Half clock cycle at 50MHz
			// This is the amount of time represented by #1 
timeprecision 1ns;


logic CLK;
logic ENABLE = 0;
logic [9:0] X = 0;
logic [8:0] Y = 200;
logic OUTPUT_READY = 0;
logic [3:0] OUTPUT_PIXEL;


RTcore RTC(CLK, ENABLE, X, Y, OUTPUT_READY, OUTPUT_PIXEL);

// These signals are internal because the processor will be 
// instantiated as a submodule in testbench.

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


always_ff @ (posedge CLK) begin
	
	if(ENABLE)
		ENABLE <= 0; // only pulse for a single clock cycle. It should be enough to set off the FSM.
	
	if(OUTPUT_READY && ~ENABLE) begin
		if (X < 639)
			X <= X + 1;
		else begin
			X <= 0;
			if(Y < 439) 
				Y <= Y + 1;
		end
		ENABLE <= 1;
	end
end


endmodule
