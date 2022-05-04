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

logic [9:0] state = 0;

logic signed [63:0] a, b, c;
logic signed [63:0] T1, T2;

logic signed [63:0] SC[64];
logic signed [127:0] LC[64]; // large caches... these are not meant to be used unless absolutely necessary


logic	[127:0]  SQRT_A_IN = 0;
logic	[63:0]  SQRT_A_OUT = 0;
logic	[64:0]  SQRT_A_REMAINDER = 0; // dont care about this 


logic	[127:0]  SQRT_B_IN = 0;
logic	[63:0]  SQRT_B_OUT = 0;
logic	[64:0]  SQRT_B_REMAINDER = 0; // dont care about this 

// Result requires 10 clock cycles. We'll give it 100 clocks anyway
sqrt SQRT_A (
	MAIN_CLK,
	SQRT_A_IN,
	SQRT_A_OUT,
	SQRT_A_REMAINDER);

always_ff @ (posedge CLK) begin

	case(state) 
	
	10'd0 : begin // reset state
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
	
	10'd1 : begin // compute a, c
		a <= (p1[0] - p0[0]) * (p1[0] - p0[0]) + (p1[1] - p0[1]) * (p1[1] - p0[1]) + (p1[2] - p0[2]) * (p1[2] - p0[2]); // distance between points
		b <= 2 * (p1[0] - p0[0]) * ( p0[0] - sphere[0]) + 2 * (p1[1] - p0[1]) * ( p0[1] - sphere[1]) + 2 * (p1[2] - p0[2]) * ( p0[2] - sphere[2]);
		c <= ( p0[0] - sphere[0]) * ( p0[0] - sphere[0]) + ( p0[1] - sphere[1]) * ( p0[1] - sphere[1]) + ( p0[2] - sphere[2]) * ( p0[2] - sphere[2]) - sphere[3] * sphere[3];
		state <= state + 1;
	end
	
	10'd10 : begin // check condition
	
		LC[0] <= b * b;
		LC[1] <= 4 * a * c;
	
		state <= state + 1;
	end
	
	10'd20 : begin
		if(LC[0] > LC[1]) begin // collision
			reg_COLLIDE <= 1'b1;
			state <= state + 1;
		end else begin // no collision
			reg_COLLIDE <= 1'b0;
			reg_READY <= 1'b1;
			state <= 0;
		end 
		
	end
	
	10'd21 : begin
		// compute up to two collision points... at least one of these will be valid.
		SQRT_A_IN <= LC[0] - LC[1]; // b^2 - 4ac
		SC[0] <= a/DEROUNDER; // rounding element
		state <= state + 1;
	end
	
	10'd31 : begin // sqrt result stable... solve quadratic (almost)
		T1 <= -b + SQRT_A_OUT - SC[0];
		T2 <= -b - SQRT_A_OUT - SC[0];
		SC[0] <= 2 * a;
		state <= state + 1;
	end
	
	10'd35 : begin
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
	
	10'd36 : begin
		pint0[0] = (T1 * p1[0] + (SC[0] - T1) * p0[0]) / SC[0];
      pint0[1] = (T1 * p1[1] + (SC[0] - T1) * p0[1]) / SC[0];
      pint0[2] = (T1 * p1[2] + (SC[0] - T1) * p0[2]) / SC[0];
        
      pint1[0] = (T2 * p1[0] + (SC[0] - T2) * p0[0]) / SC[0];
      pint1[1] = (T2 * p1[1] + (SC[0] - T2) * p0[1]) / SC[0];
      pint1[2] = (T2 * p1[2] + (SC[0] - T2) * p0[2]) / SC[0];
		
		state <= state + 1;
	end
	
	10'd40 : begin
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