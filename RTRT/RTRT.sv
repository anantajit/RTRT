module RTRT(
		///////// Clocks /////////
      input    CLK,

      ///////// KEY /////////
      input    [ 1: 0]   KEY,

      ///////// SW /////////
      input    [ 9: 0]   SW,

      ///////// LEDR /////////
      output   [ 9: 0]   LEDR,

      ///////// HEX /////////
      output   [ 7: 0]   HEX0,
      output   [ 7: 0]   HEX1,
      output   [ 7: 0]   HEX2,
      output   [ 7: 0]   HEX3,
      output   [ 7: 0]   HEX4,
      output   [ 7: 0]   HEX5,

      ///////// VGA /////////
      output             VGA_HS,
      output             VGA_VS,
      output   [ 3: 0]   VGA_R,
      output   [ 3: 0]   VGA_G,
      output   [ 3: 0]   VGA_B
);

// c0 is the clock for the circuit, c1 is only for DRAM (phase delay)
logic MAIN_CLK, c1, locked;

logic RESET;
assign RESET = ~KEY[0];

sdram_pll SDRAM_PLL (RESET, CLK, MAIN_CLK, c1, locked); // use c1 for DRAM (for now, we have no DRAM), c0 for everything else
  
HexDriver hex0(LEDR[3:0], {1'b1, HEX0});

logic [15:0] OCM_ADDR_A, OCM_ADDR_B, OCM_DATAIN_A, OCM_DATAIN_B, OCM_DATAOUT_A, OCM_DATAOUT_B;
logic OCM_WE_A, OCM_WE_B;

/*
A_READ -> used for VGA output
A_WRITE -> used by the RT cores

B -> used for the frame buffer manager
*/							 

//ocm ONCHIP(
//	OCM_ADDR_A,
//	OCM_ADDR_B,
//	MAIN_CLK,
//	OCM_DATAIN_A,
//	OCM_DATAIN_B,
//	OCM_WE_A,
//	OCM_WE_B,
//	OCM_DATAOUT_A,
//	OCM_DATAOUT_B);

// Single port test for frame buffer in OCM alone
test_ocm ONCHIP  (
	OCM_ADDR_A,
	MAIN_CLK,
	OCM_DATAIN_A,
	OCM_WE_A,
	OCM_DATAOUT_A);

always_comb begin
	if(~blank) begin
		VGA_R = 0;
		VGA_B = 0;
		VGA_G = 0;
	end else begin
		if((DrawX/20)%2 ^ (DrawY/20)%2) begin
			VGA_R = 4'b1111;
			VGA_B = 0;
			VGA_G = 0;
		end else begin
			VGA_R = 4'b0;
			VGA_B = 0;
			VGA_G = 0;
		end
	end

end

logic  [9:0] DrawX, DrawY;
logic pixel_clk, blank, sync;

vga_controller VGA_CONTROLLER (MAIN_CLK, RESET, VGA_HS,        // Horizontal sync pulse.  Active low
								              VGA_VS,        // Vertical sync pulse.  Active low
												  pixel_clk, // 25 MHz pixel clock output
												  blank,     // Blanking interval indicator.  Active low.
												  sync,      // Composite Sync signal.  Active low.  We don't use it in this lab,
												  DrawX,     // horizontal coordinate
								              DrawY);
	
	
endmodule
