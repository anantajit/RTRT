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

logic [18:0] OCM_ADDR_A, OCM_ADDR_B;
logic [3:0] OCM_DATAIN_A, OCM_DATAIN_B, OCM_DATAOUT_A, OCM_DATAOUT_B;
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
		// Drawing code
		VGA_R = OCM_BUFF;
		VGA_B = 0;
		VGA_G = 0;
	end
end

logic  [9:0] DrawX, DrawY;
logic pixel_clk, blank, sync;

logic [9:0] RTX, RTY;

logic [1:0] OCM_STATE;
logic [3:0] OCM_BUFF;
logic [3:0] WRITE_VAL;

logic [10:0] slow_clock;

always_ff @ (posedge MAIN_CLK) begin
	OCM_STATE <= OCM_STATE + 1; // controls the state of the system
	slow_clock <= slow_clock + 1;
end

always_ff @ (posedge MAIN_CLK) begin
	if(OCM_STATE == 2'b01) begin
		// the data should be ready by now
		OCM_BUFF <= OCM_DATAOUT_A;
		
		if(slow_clock < 3'b100) begin // only update RTX if slow_clock is ticked
			if(RTX < 639)
				RTX <= RTX + 1;
			else begin
				RTX <= 0; // loop RTX
			
				if(RTY < 479)
					RTY <= RTY + 1;
				else begin
					RTY <= 0;
					WRITE_VAL <= WRITE_VAL + 1;
				end	
			end
		end
	end
end


always_comb begin
	if(OCM_STATE == 2'b00) begin // READ INIT
		OCM_ADDR_A = DrawX + 640 * DrawY; // test reading where the column doesn't matter
		OCM_WE_A = 1'b0;
		OCM_DATAIN_A = 0; // no data in
	end else if (OCM_STATE == 2'b01) begin // GET THE READ OUTPUT, WRITE DATA
		OCM_ADDR_A = RTX + 640 * RTY; // test reading where the column doesn't matter
		OCM_WE_A = 1'b1; // write enable
		if(((RTX / 64) % 2) ^ ((RTY / 64) % 2))
			OCM_DATAIN_A = WRITE_VAL; 
		else
			OCM_DATAIN_A = 4'b0011;
	end else if (OCM_STATE == 2'b10) begin
		// do nothing state... for now
		OCM_ADDR_A = 0; 
		OCM_WE_A = 0;
		OCM_DATAIN_A = 0;
	end else begin
		// do nothing state for now
		OCM_ADDR_A = 0; 
		OCM_WE_A = 0;
		OCM_DATAIN_A = 0;
	end 
end


vga_controller VGA_CONTROLLER (MAIN_CLK, RESET, VGA_HS,        // Horizontal sync pulse.  Active low
								              VGA_VS,        // Vertical sync pulse.  Active low
												  pixel_clk, // 25 MHz pixel clock output
												  blank,     // Blanking interval indicator.  Active low.
												  sync,      // Composite Sync signal.  Active low.  We don't use it in this lab,
												  DrawX,     // horizontal coordinate
								              DrawY);
	
	
endmodule
