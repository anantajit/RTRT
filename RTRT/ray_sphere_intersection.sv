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

logic signed [63:0] SC[64];
logic signed [127:0] LC[64]; // large caches... these are not meant to be used unless absolutely necessary

always_ff @ (posedge CLK) begin

	case(state) 
	
	6'd0 : begin // reset state
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
	
	6'd1 : begin // compute a, c
		a <= (p1[0] - p0[0]) * (p1[0] - p0[0]) + (p1[1] - p0[1]) * (p1[1] - p0[1]) + (p1[2] - p0[2]) * (p1[2] - p0[2]); // distance between points
		b <= 2 * (p1[0] - p0[0]) * ( p0[0] - sphere[0]) + 2 * (p1[1] - p0[1]) * ( p0[1] - sphere[1]) + 2 * (p1[2] - p0[2]) * ( p0[2] - sphere[2]);
		c <= ( p0[0] - sphere[0]) * ( p0[0] - sphere[0]) + ( p0[1] - sphere[1]) * ( p0[1] - sphere[1]) + ( p0[2] - sphere[2]) * ( p0[2] - sphere[2]) - sphere[3] * sphere[3];
		state <= state + 1;
	end
	
	6'd2 : begin // check condition
	
		LC[0] <= b * b;
		LC[1] <= 4 * a * c;
	
		state <= state + 1;
	end
	
	6'd3 : begin
		if(LC[0] > LC[1]) begin // collision
			reg_COLLIDE <= 1'b1;
		end else begin // no collision
			reg_COLLIDE <= 1'b0;
		end 
		reg_READY <= 1'b1;
		
		state <= 0;
	end
	
	default : begin
		state <= state + 1;
	end

endcase

end


endmodule