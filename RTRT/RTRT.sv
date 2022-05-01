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
      output logic  [ 7: 0]   HEX0,
      output logic   [ 7: 0]   HEX1,
      output logic   [ 7: 0]   HEX2,
      output logic   [ 7: 0]   HEX3,
      output logic   [ 7: 0]   HEX4,
      output logic   [ 7: 0]   HEX5,


      ///////// VGA /////////
      output             VGA_HS,
      output             VGA_VS,
      output logic  [ 3: 0]   VGA_R,
      output logic  [ 3: 0]   VGA_G,
      output logic  [ 3: 0]   VGA_B
);


logic MAIN_CLK, c1, locked;
  logic RESET;
  assign RESET = ~KEY[0];


sdram_pll SDRAM_PLL (RESET, CLK, MAIN_CLK, c1, locked); // use c1 for DRAM, c0 for everything else


logic [9:0] DrawX, DrawY;
logic pixel_clk, blank, sync;

vga_controller VGA_CONTROLLER (MAIN_CLK, RESET, VGA_HS,        // Horizontal sync pulse.  Active low
								              VGA_VS,        // Vertical sync pulse.  Active low
												  pixel_clk, // 25 MHz pixel clock output
												  blank,     // Blanking interval indicator.  Active low.
												  sync,      // Composite Sync signal.  Active low.  We don't use it in this lab,
												  DrawX,     // horizontal coordinate
								              DrawY);


// c0 is the clock for the circuit, c1 is only for DRAM (phase delay)


//  logic [1:0] DRAM_DQM;
//  assign DRAM_UDQM = DRAM_DQM[1];
//  assign DRAM_LDQM = DRAM_DQM[0];
//  assign DRAM_CLK = c1;
//  
 
//  logic [24:0] DRAM_ADDRESS;
//  
//  logic [1:0] DRAM_BYTE_ENABLE;
//  assign DRAM_BYTE_ENABLE = 2'd0; // ALWAYS write to entire block.... Is this a shitty idea?
//  
//  logic DRAM_CHIP_SELECT;
//  assign DRAM_CHIP_SELECT = 1'b0; // CHIP SELECT
//  
//  logic [15:0] DATA_TO_DRAM;
//  
//  logic DRAM_READ_ENABLE; // outputs from the controller
//  logic DRAM_WRITE_ENABLE;
//  
//  
//  logic DRAM_READ_READY;
//  logic DRAM_WRITE_READY;
//  logic [15:0] DATA_FROM_DRAM;
//  
//  logic [24:0] counter;
//  
//  logic [24:0] slow_clock_counter;
//   
//  always_ff @ (posedge MAIN_CLK) begin
//	slow_clock_counter <= slow_clock_counter + 1;
//  end
//  
//  
//  always_ff @ (posedge MAIN_CLK) begin  
//  if(RESET)
//	counter <= 0; // initial condition
//  
//	LEDR[9] <= DRAM_READ_READY;
//	LEDR[8] <= DRAM_WRITE_READY;
//	
//	if(counter[24] == 0) begin
//		LEDR[7:0] <= counter[7:0];
//		// do writes
//		DRAM_ADDRESS <= counter[15:0]; 
//		DRAM_WRITE_ENABLE <= 1'b0; // ACTIVE LOW
//		DATA_TO_DRAM <= 3*counter + 7;// store the square of the value in the switches 
//		if(~DRAM_WRITE_ENABLE & ~DRAM_WRITE_READY) // if trying to write and the write is successful, increment counter
//			// Understand that DRAM WRITE READY is also negative for some dumb reason?
//			counter <= counter + 1;
//	end else begin
//		DRAM_ADDRESS <= SW;
//		DATA_TO_DRAM <= 0;
//		DRAM_WRITE_ENABLE <= 1'b1; // ACTIVE LOW - NO WRITE
//		DRAM_READ_ENABLE <= 1'b0; 
//		if(~DRAM_READ_READY)
//			LEDR[7:0] <= DATA_FROM_DRAM[7:0];
//	end
//  end
//  
//HexDriver hex0(LEDR[3:0], {1'b1, HEX0});
//  
//sdram SDRAM (          // inputs:
//                         DRAM_ADDRESS, // address for access
//                         DRAM_BYTE_ENABLE, // byte enable ig. Does this matter? 
//                         DRAM_CHIP_SELECT, // Chip select
//                         DATA_TO_DRAM, // Data that needs to be written
//                         DRAM_READ_ENABLE, // Read enable
//                         DRAM_WRITE_ENABLE, // Write enable
//                         c1, // input clock for sdram module
//                         ~RESET, // Reset. Is there anything that I actually need to do here? Can it just map to a reset signal?
//
//                        // outputs:
//                         DATA_FROM_DRAM,
//                         DRAM_READ_READY,
//                         DRAM_WRITE_READY,
//                         DRAM_ADDR,
//                         DRAM_BA,
//                         DRAM_CAS_N,
//                         DRAM_CKE,
//                         DRAM_CS_N,
//                         DRAM_DQ,
//                         DRAM_DQM,
//                         DRAM_RAS_N,
//                         DRAM_WE_N
//                      );


logic [15:0] OCM_ADDR_A, OCM_ADDR_B, OCM_DATAIN_A, OCM_DATAIN_B, OCM_DATAOUT_A, OCM_DATAOUT_B;
logic OCM_WE_A, OCM_WE_B;

/*
A_READ -> used for VGA output
A_WRITE -> used by the RT cores

B -> used for the frame buffer manager
*/							 
ocm_sim ONCHIP(
	OCM_ADDR_A,
	OCM_ADDR_B,
	MAIN_CLK,
	OCM_DATAIN_A,
	OCM_DATAIN_B,
	OCM_WE_A,
	OCM_WE_B,
	OCM_DATAOUT_A,
	OCM_DATAOUT_B);
	
	
logic [3:0] R_BUFF, G_BUFF, B_BUFF;

logic[1:0] OCM_A_STATE;

logic  [9:0] RTX, RTY; // Y is at most 120, X is up to 640

always_comb begin
	if(OCM_A_STATE == 2'b00) begin
		// initiate a read
		OCM_WE_A = 1'b0; // do not write
		OCM_DATAIN_A = 0;
		OCM_ADDR_A = DrawX + 640 * (DrawY % 128);
	end else if(OCM_A_STATE == 2'b01) begin
		// update the buffer
		OCM_WE_A = 1'b0; // Do not write
		OCM_DATAIN_A = 0; // no data in... all zero
		OCM_ADDR_A = 0; // address 0... both of these should not matter
		// To truly maximize bandwidth, this should initiate the next write...
	end else begin // states 10 or 11
		OCM_WE_A = 1'b1; // enable writing to memory
		
		OCM_ADDR_A = RTX + RTY * 640; // RTY is automatically capped at 120, no mod required
	
		if( ((RTX/64)%2) ^ ((RTY/64)%2) ) // check if this RTX pair lands on a checkerboard that isn't black
			OCM_DATAIN_A = 4'b1111;
		else 
			OCM_DATAIN_A = 0;
	end

	
	if(~blank) begin
		VGA_R = 0;
		VGA_G = 0;
		VGA_B = 0;
	end else begin
		if(DrawY % 128 == 0) begin
			VGA_R = 0;
			VGA_G = 0;
			VGA_B = 4'b1111;
		end else begin
			VGA_R = R_BUFF;
			VGA_G = G_BUFF;
			VGA_B = B_BUFF;
		end
	end
	
end

assign HEX1 = RTX;
assign HEX2 = RTY;

always_ff @ (posedge MAIN_CLK or posedge RESET) begin
	OCM_A_STATE <= OCM_A_STATE + 1; // increment state every time
	
	// If writing, update this every pixel
	if(OCM_A_STATE == 2'b11) begin
		if(RTX < 639)
			RTX <= RTX + 1; // sweep RTX from 0 to 639
		else begin
			RTX <= 0; // At the end of each row, reset RTX to the beginning of the row
			// check if the next row is within bounds
			if(RTY < 127) // Sweep RTY from 0 to 127.. then freeze at 127
				RTY <= RTY + 1; // increment row
			else 
				RTY <= 0; // reset Y... higher SW means that more row should not change 
		end
	end else if(OCM_A_STATE == 2'b01) begin
		R_BUFF <= OCM_DATAOUT_A[3:0]; // last four bits are copied to R in the read state... by now the memory data should be stable
	end
	
	if(RESET) begin
		RTX <= 0;
		RTY <= 0; 
		OCM_A_STATE <= 0;
	end
	
end
	
	
endmodule
