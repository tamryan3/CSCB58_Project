module wall
	(		
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
		VGA_B   						//	VGA Blue[9:0]
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
	
	wire resetn;
	assign resetn = KEY[0];
	
	// Create the colour, x, y and writeEn wires that are inputs to the controller.
	wire [2:0] colour;
	wire [6:0] x;
	wire [6:0] y;
	wire writeEn;

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
			
	// Put your code here. Your code should produce signals x,y,colour and writeEn/plot
	// for the VGA controller, in addition to any other functionality your design may require.


	paddle_datapath paddle_d(
		.clk(CLOCK_50),			
		.resetn(KEY[0]),
		.x(x),
		.y(y),
		.colour(colour),
		.writeEn(writeEn)
		);

	// Instansiate FSM control
    // control c0(...);

endmodule


module paddle_datapath(
	input clk,
	input resetn,

	output reg [6:0] x,	// to cover range from 0-120 in X direction
	output reg [6:0] y,	// make constant to move only left and right
	output reg [2:0] colour,	// set to constant colour
	output reg writeEn
	);
	
	wire [13:0] out;
	localparam	X_MIN = 7'd5,
					X_MAX = 7'd115,
					Y_MIN = 7'd5,
					Y_MAX = 7'd115,
					black = 3'b000,
					white = 3'b111;
	
	
	wall_counter WC (
		.clk(clk),
		.resetn(resetn),
		.out(out)
	);
	
	always@(posedge clk)
	begin
		if (!resetn) begin
			x <= X_MIN;
			y <= Y_MIN;
			colour <= black;
		end
		else begin
				x <= X_MIN + out[6:0];
				y <= X_MAX + out[13:7];
				colour <= white;
				if (x == X_MIN && y >= Y_MIN  && y <= Y_MAX) begin // left
					writeEn <= 1'b1;
				end
				else if (x == X_MAX && y >= Y_MIN && y <= Y_MAX) begin// right
					writeEn <= 1'b1;
				end
				else if (y == Y_MIN && x <= X_MAX) begin // top
					writeEn <= 1'b1;
				end
				else if (y == Y_MAX && x <= X_MAX) begin// bot
					writeEn <= 1'b1;
				end
				else
					writeEn <= 1'b0;
		end
	end


endmodule


module wall_counter(
	input clk,
	input resetn,
	output reg [13:0] out 	// enough for 120 pixels
	);
	
	always@(posedge clk)
	begin
		if(!resetn)
			out <= 14'b00_0000_0000_0000;
		else if (out[6:0] == 7'b1110110) begin
			out[6:0] <= 7'b000_0000;
			out[13:7] <= out[13:7] + 1'b1;
		end
		else begin
			out <= out + 1'b1;
		end
	end
endmodule
