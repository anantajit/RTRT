/*
inputs: sphere[4], p0[3], p1[3], BOUNDED, THRESHOLD
outputs: px0[3], px1[3], READY
*/
module ray_sphere_intersection(
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

logic [5:0] state;

logic signed [63:0] a, b, c;

logic signed [63:0] SC[64];
logic signed [127:0] LC[64]; // large caches... these are not meant to be used unless absolutely necessary

always_ff @ (posedge CLK) begin

	case(state) 
	
	6'd0 : begin // reset state
		if(ENABLE) begin
			state <= state + 1;
			READY <= 0;
		end
	end
	
	6'd1 : begin // compute a, b, c
		a <= (p1[0] - p0[0]) * (p1[0] - p0[0]) + (p1[1] - p0[1]) * (p1[1] - p0[1]) + (p1[2] - p0[2]) * (p1[2] - p0[2]);
		SC[0] <= (p1[0] - p0[0]) * (p0[0] - sphere[0]);
		SC[1] <= (p1[1] - p0[1]) * (p0[1] - sphere[1]);
		SC[2] <= (p1[2] - p0[2]) * (p0[2] - sphere[2]);
		c <= (p0[0] - sphere[0]) * (p0[0] - sphere[0]) + (p0[1] - sphere[1]) * (p0[1] - sphere[1]) + (p0[2] - sphere[2]) * (p0[2] - sphere[2]) - sphere[3] * sphere[3];
		
		state <= state + 1;
	end
	
	6'd2 : begin
		b <= 2 * (SC[0] + SC[1] + SC[2]);
	end
	
	6'd3 : begin // check condition
	
		LC[0] <= b * b;
		LC[1] <= a * c;
	
		state <= state + 1;
	end
	
	6'd4 : begin
		if(LC[0] > 4 * LC[1]) begin // collision
			COLLIDE <= 1'b1;
		end else begin // no collision
			COLLIDE <= 1'b0;
		end 
		READY <= 1'b1;
		
		state <= 0;
	end
	
	default : begin
		state <= state + 1;
	end

endcase

end


endmodule