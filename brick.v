module brick
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
	
	wire [2:0] current_state;
	wire finish;
	wire [3:0] row, col;
	
	brick_control BCONTROL(
		.clock(CLOCK_50),
		.resetn(resetn),
		.finish(finish),
		.row(row),
		.col(col),
		.current_state(current_state));
		
	brick_datapath BDATAPATH(
		.clock(CLOCK_50),
		.resetn(resetn),
		.current_state(current_state),
		.row(row),
		.col(col),
		.finish(finish),
		.x(x),
		.y(y),
		.colour(colour),
		.writeEn(writeEn));
endmodule

module brick_control (
	input clock,
	input resetn,
	input finish,
	input [3:0] row, col,
	output reg [2:0] current_state);
	
	reg [2:0] next_state;
	
	localparam	Init = 3'd0,
				Draw = 3'd1,
				NextOne = 3'd2,
				NextRow = 3'd3,
				Done = 3'd4;
	
	always@(posedge clock) begin
		case (current_state)
			Init: next_state = Draw;
			Draw: next_state = (finish) ? NextOne: Draw;
			NextOne: next_state = (col == 4'd10) ? NextRow: Draw;
			NextRow: next_state = (row == 4'd8) ? Done: Draw;
			Done: next_state = Done;
		endcase
		if (!resetn)
			current_state <= Init;
		else
			current_state <= next_state;
	end
endmodule

module brick_datapath (
	input clock,
	input resetn,
	input [2:0] current_state,
	output reg [3:0] row, col,
	output reg finish,
	output reg [6:0] x, y,
	output reg [2:0] colour,
	output reg writeEn);
	
	reg [6:0] brickx, bricky;
	wire [5:0] counter;
	
	brick_counter BCOUNTER (
		.clock(clock),
		.resetn(resetn),
		.counter(counter));
	
	localparam	Init = 3'd0,
				Draw = 3'd1,
				NextOne = 3'd2,
				NextRow = 3'd3,
				Finish = 3'd4;
	
	initial begin
		colour <= 3'b001;
	end
	
	always@(posedge clock) begin
		case(current_state)
			Init: begin
				// start with 0 row complete and 0 col complete
				row <= 4'd0;
				col <= 4'd0;
				// Start drawing brick from (6,6)
				brickx <= 7'd6;
				bricky <= 7'd6;
				// Enable writeEn
				writeEn <= 1'b1;
				// Set colour
				colour <= 3'b001;
			end
			Draw: begin
				// draw the brick
				x <= brickx + counter[3:0];
				y <= bricky + counter[5:4];
				colour <= colour;
				// 
				if (counter == 6'b11_1001) begin
					finish <= 1'b1;
				end
			end
			NextOne: begin
				// update col
				col <= col + 1'b1;
				// Move to the right brick
				brickx <= brickx + 7'd10;
				// update colour
				colour <= colour + 1'b1;
				if (colour == 3'b000 || colour == 3'b111)
					colour <= 3'b001;
				// Reset finish
				finish <= 1'b0;
			end
			NextRow: begin
				// reset col and update row
				col <= 4'b0;
				row <= row + 1'b1;
				// move to the first brick of next row
				brickx <= 7'd6;
				bricky <= bricky + 7'd4;
			end
		endcase
	end
endmodule

module brick_counter(
	input clock,
	input resetn,
	output reg [5:0] counter);
	always@(posedge clock) begin
		if (!resetn)
			counter <= 6'd0;
		else if (counter[3:0] == 4'd9) begin
			counter[3:0] <= 4'd0;
			counter[5:4] <= counter[5:4] + 1'b1;
		end
		else
			counter <= counter + 1'b1;
	end
endmodule