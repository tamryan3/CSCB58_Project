module ball (
	CLOCK_50,						//	On Board 50 MHz
	// Your inputs and outputs here
   KEY,
   SW,
	// The ports below are for the VGA output.  Do not change.
	VGA_CLK,   						//	VGA Clock
	VGA_HS,							//	VGA H_SYNC
	VGA_VS,							//	VGA V_SYNC
	VGA_BLANK_N,						//	VGA BLANK
	VGA_SYNC_N,						//	VGA SYNC
	VGA_R,   						//	VGA Red[9:0]
	VGA_G,	 						//	VGA Green[9:0]
	VGA_B   
	);

	input			CLOCK_50;				//	50 MHz
	input   [9:0]   SW;
	input   [3:0]   KEY;

	// Declare your inputs and outputs here
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]

	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(writeEn),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
	defparam VGA.RESOLUTION = "160x120";
	defparam VGA.MONOCHROME = "FALSE";
	defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
	defparam VGA.BACKGROUND_IMAGE = "black.mif";
	
	wire resetn;
	assign resetn = KEY[0];
	wire [1:0] current_state, next_state;
	wire [2:0] colour;
	wire [6:0] x, y;
	wire writeEn;
	wire enable;
	wire [25:0] pulse;

	
	RateDivider RD (
		.clock(CLOCK_50),
		.resetn(resetn),
		.pulse(pulse)
	);
	
	assign enable = (pulse == 26'd833333) ? 1'b1 : 1'b0;

	ball_control BC(
		.clk(CLOCK_50),
		.resetn(resetn),
		.Enable(enable),
		.current_state(current_state),
		.next_state(next_state)
	);
	
	
	ball_datapath BD(
		.clk(CLOCK_50),
		.resetn(resetn),
		.current_state(current_state),
		.x(x),
		.y(y),
		.colour(colour),
		.writeEn(writeEn)
	);
endmodule

/*
 * Control the state of the ball
 */
module ball_control(
	input clk,
	input resetn,
	input Enable,
	output reg [1:0] current_state, next_state
	);
	
	localparam	Init = 2'b00,
					Erase = 2'b01,
					Draw = 2'b10,
					Finish = 2'b11;
	
	always@(posedge clk) begin
		case (current_state)
			Init: next_state = Finish;// Draw the ball at the starting point
			Erase: next_state = Draw;// Cover the last ball position
			Draw: next_state = Finish;// Draw the ball at the new point
			Finish: next_state = (Enable == 1'b1) ? Erase : Finish;// Send finish signal
		endcase
	end
	
	always@(posedge clk) begin
		if (!resetn)
			current_state <= Init;
		else
			current_state <= next_state;
	end
endmodule

/*
 * Draw the ball
 */
module ball_datapath(
	input clk,
	input resetn,
	input [1:0] current_state,
	output reg [6:0] x,
	output reg [6:0] y,
	output reg [2:0] colour,
	output reg writeEn
	);
	
	reg direction;
	
	localparam	down = 1'b0,
					up = 1'b1,
					Init = 2'b00,
					Erase = 2'b01,
					Draw = 2'b10,
					Finish = 2'b11;
	
	always@(posedge clk) begin
		if (!resetn) begin
			x <= 7'b011_1010;
			y <= 7'b011_1010;
			colour <= 3'b001;
			direction <= down;
			writeEn <= 1'b1;
		end
		else begin
			if (current_state == Init) begin
				x <= 7'b011_1010;
				y <= 7'b011_1010;
				colour <= 3'b111;
				direction <= down;
				writeEn <= 1'b1;
			end
			else if (current_state == Erase) begin
				x <= x;
				y <= y;
				colour <= 3'b000;
			end
			else if (current_state == Draw) begin
				x <= x;
				colour <= 3'b111;
				if (direction == up && y == 7'd6)
					direction <= down;
				else if (direction == down && y == 7'd114)
					direction <= up;
				if (direction == up)
					y <= y - 1'b1;
				else if (direction == down)
					y <= y + 1'b1;
			end
		end
	end
endmodule

/*
 * Change the clock to 60 fps
 */
module RateDivider (
	input clock,
	input resetn,
	output reg [25:0] pulse
	);
	
	always@(posedge clock) begin
		if (!resetn) begin
			pulse <= 26'd0;
		end
		else if (pulse == 26'd833333) begin
			pulse <= 26'd0;
		end
		else begin
			pulse <= pulse + 1'b1;
		end
	end	
endmodule
