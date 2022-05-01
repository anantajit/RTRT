module testbench();

timeunit 10ns;	// Half clock cycle at 100 MHz
			// This is the amount of time represented by #1 
timeprecision 1ns;

// These signals are internal because the processor will be 
// instantiated as a submodule in testbench.

///////// Clocks /////////
      logic    CLK;

      ///////// KEY /////////
      logic    [ 1: 0]   KEY;

      ///////// SW /////////
      logic    [ 9: 0]   SW;

      ///////// LEDR /////////
      logic   [ 9: 0]   LEDR;

      ///////// HEX /////////
      logic   [ 7: 0]   HEX0;
      logic   [ 7: 0]   HEX1;
      logic   [ 7: 0]   HEX2;
      logic   [ 7: 0]   HEX3;
      logic   [ 7: 0]   HEX4;
      logic   [ 7: 0]   HEX5;

      ///////// VGA /////////
      logic             VGA_HS;
      logic             VGA_VS;
      logic   [ 3: 0]   VGA_R;
      logic   [ 3: 0]   VGA_G;
      logic   [ 3: 0]   VGA_B;

RTRT RTRT(.*); // autoconnect everything



// Toggle the clock
// #1 means wait for a delay of 1 timeunit
always begin : CLOCK_GENERATION
#1 CLK = ~CLK;
end

initial begin: CLOCK_INITIALIZATION
    CLK = 0;
	 KEY[0] = 1;
end 

// Testing begins here
// The initial block is not synthesizable
// Everything happens sequentially inside an initial block
// as in a software program
initial begin: TEST_VECTORS

// We dont actually have any test vectors

#1 KEY[1] = 1;
#1 KEY[0] = 0; // reset pushed

#2 KEY[1] = 0; // other button pushed

end



endmodule
