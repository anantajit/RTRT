/*
inputs: sphere[4], p0[3], p1[3], BOUNDED, THRESHOLD
outputs: px0[3], px1[3], READY
*/



module ray_sphere_intersection(
	input CLK, 
	input ENABLE, 
	// These values are not registered, this should help with speed
	input [15:0] in_sphere[4], 
	input [15:0] in_p0[3], 
	input [15:0] in_p1[3], 
	input in_BOUNDED, 
	input [3:0] in_THRESHOLD, 
	
	output READY, 
	output COLLIDE,
	output [15:0] pint0[3], 
	output [15:0] pint1[3]);

/*
CONSTANT VALUES
*/
logic [15:0] DEROUNDER = 16'd75;
	

// SCENE
logic [15:0] sphere[4];
logic [15:0] p0[3];
logic [15:0] p1[3];
logic BOUNDED;
logic [3:0] THRESHOLD;

logic reg_COLLIDE = 0, reg_READY = 0;

assign COLLIDE = reg_COLLIDE;
assign READY = reg_READY;

logic [15:0] state = 0;

logic signed [63:0] a, b, c;
logic signed [63:0] T1, T2;

logic signed [63:0] SC[64];
logic signed [127:0] LC[64]; // large caches... these are not meant to be used unless absolutely necessary


logic	[127:0]  SQRT_A_IN = 0;
logic	[63:0]  SQRT_A_OUT = 0;
logic	[64:0]  SQRT_A_REMAINDER = 0; // dont care about this 

logic [15:0] reg_pint0[3];
assign pint0 = reg_pint0;
logic [15:0] reg_pint1[3];
assign pint1 = reg_pint1;

// Result requires 10 clock cycles. We'll give it 100 clocks anyway
sqrt SQRT_A (
	CLK,
	SQRT_A_IN,
	SQRT_A_OUT,
	SQRT_A_REMAINDER);


logic [127:0] NUM[12], QUO[12];
logic [63:0] DEN[12];

logic [127:0] MULT_A[12], MULT_B[12];
logic [127:0] PRODUCT[12];

logic [63:0] SQUARE_IN[12];
logic [127:0] SQUARE_OUT[12];




genvar i;

generate
	for (i = 0; i < 12; i++) begin: arithmetic_block
		divider divider_i(CLK, NUM[i], DEN[i], QUO[i]);
		multiplier multiplier_i(CLK, MULT_A[i], MULT_B[i], PRODUCT[i]);
		square square_i(CLK, SQUARE_IN[i], SQUARE_OUT[i]);
	end: arithmetic_block
endgenerate


always_ff @ (posedge CLK) begin

	case(state) 
	
	16'd0 : begin // reset state
		if(ENABLE) begin
			state <= state + 1;
			
			reg_READY <= 0;
			sphere <= in_sphere;
			p0 <= in_p0;
			p1 <= in_p1;
			BOUNDED <= in_BOUNDED;
			THRESHOLD <= in_THRESHOLD;
			
			reg_COLLIDE <= 0;
		end
	end
	
	16'd1 : begin 
		// A
		SQUARE_IN[0] <= p1[0] - p0[0];
		SQUARE_IN[1] <= p1[1] - p0[1];
		SQUARE_IN[2] <= p1[2] - p0[2];
		
		// B computation requires another multiplication by two for all values... keep in mind!
		MULT_A[0] <= p1[0] - p0[0];
		MULT_B[0] <= p0[0] - sphere[0];
		
		MULT_A[1] <= p1[1] - p0[1];
		MULT_B[1] <= p0[1] - sphere[1];
		
		MULT_A[2] <= p1[2] - p0[2];
		MULT_B[2] <= p0[2] - sphere[2];
		
		// C
		
		SQUARE_IN[3] <= p0[0] - sphere[0];
		SQUARE_IN[4] <= p0[1] - sphere[1];
		SQUARE_IN[5] <= p0[2] - sphere[2];
		
		SQUARE_IN[6] <= sphere[3];
		
		state <= state + 1;
	end
	
	16'd32 : begin
		a <= SQUARE_OUT[0] + SQUARE_OUT[1] + SQUARE_OUT[2];
		c <= SQUARE_OUT[3] + SQUARE_OUT[4] + SQUARE_OUT[5] - SQUARE_OUT[6];
		
		MULT_A[0] <= PRODUCT[0] + PRODUCT[1] + PRODUCT[2];
		MULT_B[0] <= 2'd2; // multiply by two
		
		state <= state + 1;
	end
	
	16'd64 : begin
		b <= PRODUCT[0];
		state <= state + 1;
		
		// A, B, C have been set!
	end
	
	16'd500 : begin // check condition
	
		SQUARE_IN[0] <= b;
		
		MULT_A[0] <= a;
		MULT_B[0] <= c;
	
		state <= state + 1;
	end
	
	16'd532 : begin
		LC[0] <= SQUARE_OUT[0];
		
		MULT_A[0] <= PRODUCT[0];
		MULT_B[0] <= 4;
		
		state <= state + 1;
	end
	
	16'd564 : begin
		LC[1] <= PRODUCT[0];
	end
	
	16'd1000 : begin
		if(LC[0] > LC[1]) begin // collision
			reg_COLLIDE <= 1'b1;
			state <= state + 1;
		end else begin // no collision
			reg_COLLIDE <= 1'b0;
			reg_READY <= 1'b1;
			state <= 0;
		end 
		
	end
	
	16'd1500 : begin
		// compute up to two collision points... at least one of these will be valid.
		SQRT_A_IN <= LC[0] - LC[1]; // b^2 - 4ac
		NUM[0] <= a;
		DEN[0] <= DEROUNDER;
		state <= state + 1;
	end
	
	16'd1600 : begin
		SC[0] <= QUO[0];
		state <= state + 1;
	end
	
	16'd2000 : begin // sqrt result stable... solve quadratic (almost)
		T1 <= -b + SQRT_A_OUT - SC[0];
		T2 <= -b - SQRT_A_OUT - SC[0];
		SC[0] <= 2 * a; // I sure hope we can do this in one clock cycle :(
		state <= state + 1;
	end
	
	16'd2500 : begin
		if(T1 < THRESHOLD && T2 < THRESHOLD) begin // too close to call without rounding error
			// ignore collision... return 0
			state <= 0;
			reg_COLLIDE <= 1'b0;
			reg_READY <= 1'b1;
		end else if (a == 0) begin // infinite distance collision... should not be possible
			// ignore collision... return 0
			state <= 0;
			reg_COLLIDE <= 1'b0;
			reg_READY <= 1'b1;
		end else if (BOUNDED && (T1 > SC[0]) && (T2 > SC[0])) begin // bounded, but out of bounds
			// ignore collision... return 0
			state <= 0;
			reg_COLLIDE <= 1'b0;
			reg_READY <= 1'b1;
		end else begin // compute specifics
			state <= state + 1;
		end
	end
	
	16'd2900 : begin
		MULT_A[0] <= T1;
		MULT_B[0] <= p1[0];
		
		MULT_A[1] <= SC[0] - T1;
		MULT_B[1] <= p0[0];
		
		MULT_A[2] <= T1;
		MULT_B[2] <= p1[1];
		
		MULT_A[3] <= SC[0] - T1;
		MULT_B[3] <= p0[1];
		
		MULT_A[4] <= T1;
		MULT_B[4] <= p1[2];
		
		MULT_A[5] <= SC[0] - T1;
		MULT_B[5] <= p0[2];
		
		MULT_A[6] <= T1;
		MULT_B[6] <= p1[0];
		
		MULT_A[7] <= SC[0] - T2;
		MULT_B[7] <= p0[0];
		
		MULT_A[8] <= T2;
		MULT_B[8] <= p1[1];
		
		MULT_A[9] <= SC[0] - T2;
		MULT_B[9] <= p0[1];
		
		MULT_A[10] <= T2;
		MULT_B[10] <= p1[2];
		
		MULT_A[11] <= SC[0] - T2;
		MULT_B[11] <= p0[2];
		
		
	end
	
	16'd3000 : begin
		NUM[0] <= PRODUCT[0] + PRODUCT[1];
		DEN[0] <= SC[0];
		
		NUM[1] <= PRODUCT[2] + PRODUCT[3];
		DEN[1] <= SC[0];
		
		NUM[2] <= PRODUCT[4] + PRODUCT[5];
		DEN[2] <= SC[0];
		
		NUM[3] <= PRODUCT[6] + PRODUCT[7];
		DEN[3] <= SC[0];
		
		NUM[4] <= PRODUCT[8] + PRODUCT[9];
		DEN[4] <= SC[0];
		
		NUM[5] <= PRODUCT[10] + PRODUCT[11];
		DEN[5] <= SC[0];
		
		state <= state + 1;
	end
	
	16'd3200 : begin
		reg_pint0[0] <= QUO[0];
		reg_pint0[1] <= QUO[1];
		reg_pint0[2] <= QUO[2];
	
		reg_pint1[0] <= QUO[3];
		reg_pint1[1] <= QUO[4];
		reg_pint1[2] <= QUO[5];
		
		state <= state + 1;
	end
	
	16'd3500 : begin
		state <= 0;
		reg_COLLIDE <= 1'b1;
		reg_READY <= 1'b1;
	end
	
	default : begin
		state <= state + 1;
	end

endcase

end


endmodule