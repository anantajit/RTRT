/*
This is a massive state machine that runs through the raytracing code. It accepts the scene data as inputs, but the mechanism for this still needs to be determined. 
*/

// TODO: we require optimizations for this code. 

 module RTcore(input CLK, input ENABLE, input[9:0] X_in, input[8:0] Y_in, output OUTPUT_READY, output[3:0] OUTPUT_PIXEL, input [9:0] SW);
 // given an X, Y, returns the output
 
 logic reg_OUTPUT_READY = 1'b1; // initialize to allow writing
 assign OUTPUT_READY = reg_OUTPUT_READY;
 logic [3:0] reg_OUTPUT_PIXEL;
 assign OUTPUT_PIXEL = reg_OUTPUT_PIXEL;
 
 logic [9:0] X = 0;
 logic [8:0] Y = 0;

/* HARDCODE SCENE FOR NOW */
logic [15:0] f = 16'd1000;
logic [15:0] sphere[4] = '{16'd320, 16'd240,  16'd1100, 16'd100}; // ball centered on a screen
logic [15:0] light[4] = '{16'd50, 16'd50, 16'd1000, 16'h0FFF}; // light source with full intensity. We leave the leading bit 0 for sign issues
logic [15:0] camera[3] = '{16'd320, 16'd240, 0};
logic [63:0] INTENSITY_CALIBRATION;
assign INTENSITY_CALIBRATION = SW[9:0];


//RSI controls
logic RSI_ENABLE;
logic [15:0] RSI_p0[3];
logic [15:0] RSI_p1[3];
logic RSI_BOUNDED;
logic [3:0] RSI_THRESHOLD;


// RSI OUTPUTS
logic RSI_READY;
logic RSI_COLLIDE;
logic [15:0] RSI_pint0[3];
logic [15:0] RSI_pint1[3];


divider divider_i(CLK, NUM, DEN, QUO);
multiplier multiplier_i(CLK, MULT_A, MULT_B, PRODUCT);
square square_0(CLK, SQUARE_IN[0], SQUARE_OUT[0]);
square square_1(CLK, SQUARE_IN[1], SQUARE_OUT[1]);
square square_2(CLK, SQUARE_IN[2], SQUARE_OUT[2]);

logic signed [127:0] NUM, QUO;
logic signed [63:0] DEN;

logic signed [127:0] MULT_A, MULT_B;
logic signed [127:0] PRODUCT;

logic signed [63:0] SQUARE_IN[3];
logic signed [127:0] SQUARE_OUT[3];


ray_sphere_intersection RSI(CLK, RSI_ENABLE, sphere, RSI_p0, RSI_p1, RSI_BOUNDED, RSI_THRESHOLD, 
									RSI_READY, RSI_COLLIDE, RSI_pint0, RSI_pint1);

 
logic [9:0] state = 0;

logic [15:0] screen_pixel[3];
logic [15:0] light_position[3];


always_ff @ (posedge CLK) begin

	case(state) 
	
	6'd0 : begin // reset state
		if(ENABLE) begin // if the RTcore is required to process a pixel,
			state <= state + 1;
			X <= X_in;
			Y <= Y_in;
			// Set the screen pixel
			screen_pixel[0] <= X;
			screen_pixel[1] <= Y;
			screen_pixel[2] <= f;
			reg_OUTPUT_READY <= 1'b0; 
			
			if(X == 0 && Y == 0) begin // every time we hit the top corner, move circle to the right
				// increment pixel test
				if(sphere[0] < 540)
					sphere[0] <= sphere[0] + 5;
				else
					sphere[0] <= 100;
			end
			
		end
	end
	
	6'd1 : begin // check if the ray intersects the sphere
		RSI_ENABLE <= 1'b1; // enable intersector
		RSI_p0 <= camera; // start the ray from the camera
		RSI_p1 <= screen_pixel; // set the destination ray on the screen
		RSI_BOUNDED <= 1'b0; // not bounded collision
		RSI_THRESHOLD <= 4'b0; // no threshold required (exact value)
		state <= state + 1;
	end
	
	6'd3 : begin // wait state
		RSI_ENABLE <= 1'b0; // stop the enable (only one calculation)
		if(RSI_READY) begin
			state <= state + 1;
		end
	end
	
	6'd4 : begin
		// the collision result is ready
		if(RSI_COLLIDE) begin
			state <= state + 1;
			// copy the light's position
			light_position[0] <= light[0];
			light_position[1] <= light[1];
			light_position[2] <= light[2];
		end else begin
			reg_OUTPUT_PIXEL <= 4'b0; // color black
			reg_OUTPUT_READY <= 1'b1;
			state <= 0; // reset state
		end
	end
	
	6'd5 : begin 
	
		// check if the ray to this light source intersects the sphere at any points.
		RSI_ENABLE <= 1'b1; // enable intersector
		RSI_p0 <= RSI_pint1; // start the ray from the closest intersection point
		RSI_p1 <= light_position; // set the destination ray as the light source
		RSI_BOUNDED <= 1'b1; // bounded collision
		RSI_THRESHOLD <= 4'd10; // threshold of 10, worked in sim
		state <= state + 1;
	
	end
	
	6'd7 : begin // wait state
		RSI_ENABLE <= 1'b0; // stop the enable (only one calculation)
		if(RSI_READY) begin
			state <= state + 1;
		end
	end
	
	6'd9 : begin
		if(RSI_COLLIDE) begin // this area is blocked by the sphere
			reg_OUTPUT_PIXEL <= 4'b10; // color dark grey
			reg_OUTPUT_READY <= 1'b1;
			state <= 0; // reset state
		end else begin
			SQUARE_IN[0] <= light[0] - RSI_p0[0];
			SQUARE_IN[1] <= light[1] - RSI_p0[1];
			SQUARE_IN[2] <= light[2] - RSI_p0[2];
			
			MULT_A <= light[3];
			MULT_B <= INTENSITY_CALIBRATION;
			state <= state + 1;
		end
	end
	
	6'd41 : begin
		// Squaring and multiplication is completed
		DEN <= SQUARE_OUT[0] + SQUARE_OUT[1] + SQUARE_OUT[2];
		NUM <= PRODUCT;
		state <= state + 1;
	end
	
	9'd105 : begin
		// QUO contains a valid result
				
		reg_OUTPUT_READY <= 1'b1;
		
		state <= 0;
		
		if(QUO > 4'b1111)
			reg_OUTPUT_PIXEL <= 4'b1111;
		else
			reg_OUTPUT_PIXEL <= QUO[3:0];

	end
	
	default : begin
		state <= state + 1;
	end

endcase

end
 
 endmodule