`timescale 1ns / 1ns

module project (
	// default 50MHz clock
	CLOCK_50,
	// FPGA board input
	KEY,
	SW,
	// VGA output
	VGA_CLK,
	VGA_HS,
	VGA_VS,
	VGA_BLANK_N,
	VGA_SYNC_N,
	VGA_R,
	VGA_G,
	VGA_B);
	// set types
	input CLOCK_50;
	input [9:0] SW;
	input [3:0] KEY;
	output VGA_CLK;
	output VGA_HS;
	output VGA_VS;
	output VGA_BLANK_N;
	output VGA_SYNC_N;
	output [9:0] VGA_R;
	output [9:0] VGA_G;
	output [9:0] VGA_B;
	
	// VGA adapter
	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(writeEn),
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
	
	// declare input and output
	wire [2:0] colour; // (R,G,B)
	wire resetn; // Restart Signal
	assign resetn = SW[9]; // Assign Restart Button
	wire writeEn; // Write Enable Signal
	wire [6:0] x; // from 0 to 127
	wire [6:0] y; // from 0 to 127
	
	wire ballerasefinish;
	wire ballfinish;
	wire brickerasefinish;
	wire brickfinish;
	wire brickhit;
	wire gameover;
	wire paddleerasefinish;
	wire paddlefinish;
	wire resetfinish;
	wire wallfinish;
	wire [4:0] current_state;
	
	// FSM of overall project
	control CONT(
		.ballerasefinish(ballerasefinish),
		.ballfinish(ballfinish),
		.brickerasefinish(brickerasefinish),
		.brickfinish(brickfinish),
		.brickhit(brickhit),
		.clock(CLOCK_50),
		.gameover(gameover),
		.paddleerasefinish(paddleerasefinish),
		.paddlefinish(paddlefinish),
		.resetfinish(resetfinish),
		.resetn(resetn),
		.wallfinish(wallfinish),
		.current_state(current_state)
	);
	// Drawing
	datapath DATA(
		.clock(CLOCK_50),
		.current_state(current_state),
		.left(~KEY[3]),
		.resetn(resetn),
		.right(~KEY[2]),
		.ballerasefinish(ballerasefinish),
		.ballfinish(ballfinish),
		.brickerasefinish(brickerasefinish),
		.brickfinish(brickfinish),
		.brickhit(brickhit),
		.colour(colour),
		.gameover(gameover),
		.paddleerasefinish(paddleerasefinish),
		.paddlefinish(paddlefinish),
		.resetfinish(resetfinish),
		.wallfinish(wallfinish),
		.writeEn(writeEn),
		.x(x),
		.y(y)
	);
endmodule

module control(
	input ballerasefinish,
	input ballfinish,
	input brickerasefinish,
	input brickfinish,
	input brickhit,
	input clock,
	input gameover,
	input paddleerasefinish,
	input paddlefinish,
	input resetfinish,
	input resetn,
	input wallfinish,
	output reg [4:0] current_state);

	reg [4:0] next_state;

	wire move;
	wire [25:0] secondpulse;

	// State
	localparam	start = 5'd0, // Initialize all the finish signal
				drawwall = 5'd1, // Draw the four walls
				walldone = 5'd2, // Finish drawing walls
				initpaddle = 5'd3, // Draw the paddle for first time
				erasepaddle = 5'd4, // Erase the paddle based on left and right button
				drawpaddle = 5'd5, // Update paddle based on left and right button
				paddledone = 5'd6, // Finish drawing paddle
				initball = 5'd7, // Draw the ball for first time
				eraseball = 5'd8, // Erase the ball based on the direction
				drawball = 5'd9, // Update the ball based on the direction
				balldone = 5'd10, // Finish drawing ball
				initbrick = 5'd11, // Draw the bricks for the first time
				erasebrick = 5'd12, // Erase the brick if balls hit
				brickdone = 5'd13, // Finish updating the brick
				update = 5'd14, // Update the game situation
				reset = 5'd15, // Restart the game
				resetdone = 5'd16; // Finish erasing everything
	
	MovePerSecond MPS (
		.clock(clock),
		.secondpulse(secondpulse));
	
	// will be 1 every 1/60 seconds
	assign move = (secondpulse == 26'd833333) ? 1'd1 : 1'd0;
	
	always@(posedge clock) begin
		case (current_state)
			start: next_state = drawwall;
			drawwall: next_state = (wallfinish) ? walldone : drawwall;
			walldone: next_state = initpaddle;
			initpaddle: next_state = (paddlefinish) ? initball : initpaddle;
			initball: next_state = (ballfinish) ? initbrick : initball;
			initbrick: next_state = (brickfinish) ? update : initbrick;
			update: next_state = (gameover) ? start : erasepaddle;
			erasepaddle: next_state = (paddleerasefinish) ? drawpaddle : erasepaddle;
			drawpaddle: next_state = (paddlefinish) ? paddledone : drawpaddle;
			paddledone: next_state = eraseball;
			eraseball: next_state = (ballerasefinish) ? drawball : eraseball;
			drawball: next_state = (ballfinish) ? balldone : drawball ;
			balldone: next_state = (brickhit) ? erasebrick : update;
			erasebrick: next_state = (brickerasefinish) ? brickdone : erasebrick;
			brickdone: next_state = update;
			reset: next_state = (resetfinish) ? resetdone : reset;
			resetdone : next_state = start;
			default: next_state = start;
		endcase
	end
	
	always@(posedge clock) begin
		if (resetn) begin
			current_state <= reset;
		end
		else begin
			current_state <= next_state;
		end
	end
endmodule

module datapath (
	input clock,
	input [4:0] current_state,
	input left,
	input resetn,
	input right,
	output reg ballerasefinish,
	output reg ballfinish,
	output reg brickerasefinish,
	output reg brickfinish,
	output reg brickhit,
	output reg [2:0] colour,
	output reg gameover,
	output reg paddleerasefinish,
	output reg paddlefinish,
	output reg resetfinish,
	output reg wallfinish,
	output reg writeEn,
	output reg [6:0] x,
	output reg [6:0] y);
	
	reg [3:0] direction;
	reg [6:0] ball_x;
	reg [6:0] ball_y;
	reg [14:0] brick_status1;
	reg [14:0] brick_status2;
	reg [14:0] brick_status3;
	reg [14:0] brick_status4;
	reg [6:0] hit_x;
	reg [6:0] hit_y;
	reg [6:0] paddle_x;
	reg [6:0] paddle_y;
	reg [6:0] x_change;
	reg [6:0] y_change;
	
	reg wallenable;
	wire [13:0] wallout;
	reg paddleenable;
	wire [2:0] paddleout;
	reg resetenable;
	wire [13:0] resetout;
	reg brickenable;
	wire [13:0] brickout;
	wire [2:0] singlebrickout;
	

	// direction
	localparam	Up = 4'd0,
				UpRight = 4'd1,
				RightUp = 4'd2,
				UpLeft = 4'd3,
				LeftUp = 4'd4,
				Down = 4'd5,
				DownRight = 4'd6,
				RightDown = 4'd7,
				DownLeft = 4'd8,
				LeftDown = 4'd9;

	// brick information
	localparam	BrickWidth = 4'd5,
  				BrickHeight = 1'd1,
				Brickx1 = 7'd23,
				Brickx2 = 7'd28,
				Brickx3 = 7'd33,
				Brickx4 = 7'd38,
				Brickx5 = 7'd43,
				Brickx6 = 7'd48,
				Brickx7 = 7'd53,
				Brickx8 = 7'd58,
				Brickx9 = 7'd63,
				Brickx10 = 7'd68,
				Brickx11 = 7'd73,
				Brickx12 = 7'd78,
				Brickx13 = 7'd83,
				Brickx14 = 7'd88,
				Brickx15 = 7'd93,
				Bricky1 = 7'd7,
				Bricky2 = 7'd8,
				Bricky3 = 7'd9,
				Bricky4 = 7'd10;

	// ball information
	localparam	BallMin = 7'd6,
  				BallMax = 7'd114;

	// State
	localparam	start = 5'd0, // Initialize all the finish signal
				drawwall = 5'd1, // Draw the four walls
				walldone = 5'd2, // Finish drawing walls
				initpaddle = 5'd3, // Draw the paddle for first time
				erasepaddle = 5'd4, // Erase the paddle based on left and right button
				drawpaddle = 5'd5, // Update paddle based on left and right button
				paddledone = 5'd6, // Finish drawing paddle
				initball = 5'd7, // Draw the ball for first time
				eraseball = 5'd8, // Erase the ball based on the direction
				drawball = 5'd9, // Update the ball based on the direction
				balldone = 5'd10, // Finish drawing ball
				initbrick = 5'd11, // Draw the bricks for the first time
				erasebrick = 5'd12, // Erase the brick if balls hit
				brickdone = 5'd13, // Finish updating the brick
				update = 5'd14,
				reset = 5'd15, // Restart the game
				resetdone = 5'd16; // Finish erasing everything
				
	// the counter use to draw the walls
	wallcounter WALLCOUNT(
		.clock(clock),
		.wallenable(wallenable),
		.wallout(wallout));
	
	// the counter use to draw the paddle
	paddlecounter PADDLECOUNT(
		.clock(clock),
		.paddleenable(paddleenable),
		.paddleout(paddleout));
	
	singlebrickcounter SINGLECOUNT(
		.clock(clock),
		.brickenable(brickenable),
		.singlebrickout(singlebrickout));
	
	// the counter use to reset the game
	resetcounter RESETCOUNT(
		.clock(clock),
		.resetenable(resetenable),
		.resetout(resetout));
	
	always@(posedge clock) begin
		case (current_state)
			start: begin
				// initialize all the finish signals
				ballerasefinish <= 1'b0;
				ballfinish <= 1'b0;
				brickerasefinish <= 1'b0;
				brickfinish <= 1'b0;
				brickhit <= 1'b0;
				// set colour to background colour to ensure nothing is draw
				colour <= 3'b000;
				gameover <= 1'b0;
				paddleerasefinish <= 1'b0;
				paddlefinish <= 1'b0;
				resetfinish <= 1'b0;
				wallfinish <= 1'b0;
				// disable drawing
				writeEn <= 1'b0;
			end
			drawwall: begin
				// enable counter to start counting
				wallenable <= 1'b1;
				// start drawing from (5,5) to (115,115)
				x <= 7'd5 + wallout[6:0];
				y <= 7'd5 + wallout[13:7];
				// draw wall in white colour
				colour <= 3'b111;
				if (x == 7'd5 && y <= 7'd115 || // left wall (5, Y)
					x == 7'd115 && y <= 7'd115 || // right wall (115, Y)
					y == 7'd5 && y <= 7'd115 || // top wall (X, 5)
					y == 7'd115 && y <= 7'd115) // bottom wall (X, 115)
					writeEn <= 1'b1; // only draw when the current position is the wall
				else
					writeEn <= 1'b0; // disable drawing for position that is not the wall
				if (x > 7'd115 && y > 7'd115)
					// when the current position exceeds (115,115), go to next state
					wallfinish <= 1'b1;
			end
			walldone: begin
				// reset wall counter for next run
				wallenable <= 1'b0;
				// reset wall finish signal for next run
				wallfinish <= 1'b0;
				// disable drawing
				writeEn <= 1'b0;
			end
			initpaddle: begin
				// enable paddle counter
				paddleenable <= 1'b1;
				// default paddle position will be (58,100) to (62, 100)
				paddle_x <= 7'd58;
				paddle_y <= 7'd100;
				// paddle in green
				colour <= 3'b010;
				// Starting drawing from (58,100)
				x <= paddle_x + paddleout;
				y <= paddle_y;
				if (x >= paddle_x && x <= paddle_x + 7'd4)
					writeEn <= 1'b1; // enable drawing when the current is in paddle position
				else
					writeEn <= 1'b0; // disable drawing for other pixel than the paddle
				if (x > paddle_x + 7'd4)
					paddlefinish <= 1'b1; // go to next state when the counter exceeds 4
			end
			erasepaddle: begin
				// if left button is pressed but not right button
				if (left && !right) begin
					// if the paddle is not in the left most (beside left wall)
					if (paddle_x > 7'd6) begin
						// enable drawing
						writeEn <= 1'b1;
						// change colour to black (background colour)
						colour <= 3'b000;
						// overdraw the right most pixel (tail)
						x <= paddle_x + 7'd4;
						y <= paddle_y;
					end
				end
				// if right button is pressed but not left button
				else if (right && !left) begin
					// if paddle is not in the right most (beside right wall)
					if (paddle_x < 7'd114) begin
						// enable drawing
						writeEn <= 1'b1;
						// change colour to background colour
						colour <= 3'b000;
						// overdraw the left most pixel (head)
						x <= paddle_x;
						y <= paddle_y;
					end
				end
				// if both buttons are pressed or both buttons are not pressed
				else begin
					// disable drawing
					writeEn <= 1'b0;
				end
				// move to next state
				paddleerasefinish <= 1'b1;
			end
			drawpaddle: begin
				// enable drawing
				writeEn <= 1'b1;
				// enable counter
				paddleenable <= 1'b1;
				// set colour to green
				colour <= 3'b010;
				// if left is pressed but not right
				if (left && !right) begin
					// if paddle can still move left
					if (paddle_x > 7'd6) begin
						// head move left 1 pixel
						paddle_x <= paddle_x - 1'b1;
					end
				end
				// if right is pressed but not left
				else if (right && !left) begin
					// if paddle can still move right
					if (paddle_x < 7'd114) begin
						// head move right 1 pixel
						paddle_x <= paddle_x + 1'b1;
					end
				end
				// start drawing new paddle
				x <= paddle_x + paddleout;
				y <= paddle_y;
				if (x >= paddle_x && x <= paddle_x + 7'd4)
					writeEn <= 1'b1;
				else
					writeEn <= 1'b0;
				if (x > paddle_x + 7'd4)
					paddlefinish <= 1'b1;
			end
			paddledone: begin
				// disable drawing
				writeEn <= 1'b0;
				// reset finish signal for next use
				paddleerasefinish <= 1'b0;
				paddlefinish <= 1'b0;
				// reset paddle counter for next use
				paddleenable <= 1'b0;
			end
			initball: begin
				// ball default location (58,58)
				ball_x <= 7'd58;
				ball_y <= 7'd58;
				// draw ball at default location
				x <= ball_x;
				y <= ball_y;
				// draw ball at white
				colour <= 3'b111;
				// enable drawing
				writeEn <= 1'b1;
				// default direction is S
				direction <= Down;
				// ball finish signal on
				ballfinish <= 1'b1;
			end
			eraseball: begin
				// enable drawing
				writeEn <= 1'b1;
				// change colour to background colour
				colour <= 3'b000;
				// overdraw the ball pixel
				x <= ball_x;
				y <= ball_y;
				// move to next state
				ballerasefinish <= 1'b1;
			end
			drawball: begin
				// Hit Top Left Corner
				if (ball_x == BallMin && ball_y == BallMin) begin
					if (direction == UpLeft)
						direction <= DownRight;
					else if (direction == LeftUp)
						direction <= RightDown;
					else 
						direction <= direction;
					ball_x <= ball_x + x_change;
					ball_y <= ball_y + y_change;
				end
				else if (ball_x == BallMin + 1'b1 && ball_y == BallMin) begin
					if (direction == LeftUp) begin
						direction <= RightDown;
						ball_x <= ball_x;
						ball_y <= ball_y;
					end
					else begin
						direction <= direction;
						ball_x <= ball_x + x_change;
						ball_y <= ball_y + y_change;
					end
				end
				// Hit Top Right Corner
				else if (ball_x == BallMax && ball_y == BallMin) begin
					if (direction == UpRight)
						direction <= DownLeft;
					else if (direction == RightUp)
						direction <= LeftDown;
					else
						direction <= direction;
					ball_x <= ball_x + x_change;
					ball_y <= ball_y + y_change;
				end
				else if (ball_x == BallMax - 1'b1 && ball_y == BallMin) begin
					if (direction == RightUp) begin
						direction <= LeftDown;
						ball_x <= ball_x;
						ball_y <= ball_y;
					end
					else begin
						direction <= direction;
						ball_x <= ball_x + x_change;
						ball_y <= ball_y + y_change;
					end
				end
				// Hit Top
				else if (ball_y == BallMin && ball_x != BallMin && ball_x != BallMax) begin
					if (direction == Up)
						direction <= Down;
					else if (direction == UpRight)
						direction <= DownRight;
					else if (direction == RightUp)
						direction <= RightDown;
					else if (direction == UpLeft)
						direction <= DownLeft;
					else if (direction == LeftUp)
						direction <= LeftDown;
					else
						direction <= direction;
					ball_x <= ball_x + x_change;
					ball_y <= ball_y + y_change;
				end
				// Hit Left
				else if (ball_x == BallMin) begin
					if (direction == UpLeft)
						direction <= UpRight;
					else if (direction == DownLeft)
						direction <= DownRight;
					else if (direction == LeftUp)
						direction <= RightUp;
					else if (direction == LeftDown)
						direction <= RightDown;
					else
						direction <= direction;
					ball_x <= ball_x + x_change;
					ball_y <= ball_y + y_change;
				end
				else if (ball_x == BallMin + 1'b1) begin
					if (direction == LeftUp) begin
						direction <= RightUp;
						ball_x <= ball_x;
						ball_y <= ball_y - 7'd2;
					end
					else if (direction == LeftDown) begin
						direction <= RightDown;
						ball_x <= ball_x;
						ball_y <= ball_y + 7'd2;
					end
					else begin
						direction <= direction;
						ball_x <= ball_x + x_change;
						ball_y <= ball_y + y_change;
					end
				end
				// Hit Right
				else if (ball_x == BallMax) begin
					if (direction == UpRight)
						direction <= UpLeft;
					else if (direction == DownRight)
						direction <= DownLeft;
					else if (direction == RightUp)
						direction <= LeftUp;
					else if (direction == RightDown)
						direction <= LeftDown;
					else
						direction <= direction;
					ball_x <= ball_x + x_change;
					ball_y <= ball_y + y_change;
				end
				else if (ball_x == BallMax - 1'b1) begin
					if (direction == RightUp) begin
						direction <= LeftUp;
						ball_x <= ball_x;
						ball_y <= ball_y - 7'd2;
					end
					else if (direction == RightDown) begin
						direction <= LeftDown;
						ball_x <= ball_x;
						ball_y <= ball_y + 7'd2;
					end
					else begin
						direction <= direction;
						ball_x <= ball_x + x_change;
						ball_y <= ball_y + y_change;
					end
				end
				// Hit Bottom (Game Over)
				else if (ball_y >= BallMax) begin
					gameover <= 1'b1;
				end
				// Hit Nothing
				else begin
					direction <= direction;
					ball_x <= ball_x + x_change;
					ball_y <= ball_y + y_change;
				end
			// Hit Paddle
			if (ball_y + y_change >= paddle_y - 7'd1) begin
				if (ball_x + x_change == paddle_x)
					direction <= LeftUp;
				else if (ball_x + x_change == paddle_x + 7'd1)
					direction <= UpLeft;
				else if (ball_x + x_change == paddle_x + 7'd2)
					direction <= Up;
				else if (ball_x + x_change == paddle_x + 7'd3)
					direction <= UpRight;
				else if (ball_x + x_change == paddle_x + 7'd4)
					direction <= RightUp;
				else
					direction <= direction;
			ball_x <= ball_x + x_change;
			ball_y <= ball_y + y_change;
			end
			// Hit Brick
			// Hit Row 1 (Topest Row)
			if (ball_y + y_change == Bricky1) begin
				// Brick 1 area & Brick 1 exists
				if (ball_x + x_change >= Brickx1 && ball_x + x_change < Brickx2 && brick_status1[0] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx1;
				end
				// Brick 2 area & Brick 2 exists
				else if (ball_x + x_change >= Brickx2 && ball_x + x_change < Brickx3 && brick_status1[1] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx2;
				end
				// Brick 3 area & Brick 3 exists
				else if (ball_x + x_change >= Brickx3 && ball_x + x_change < Brickx4 && brick_status1[2] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx3;
				end
				// Brick 4 area & Brick 4 exists
				else if (ball_x + x_change >= Brickx4 && ball_x + x_change < Brickx5 && brick_status1[3] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx4;
				end
				// Brick 5 area & Brick 5 exists
				else if (ball_x + x_change >= Brickx5 && ball_x + x_change < Brickx6 && brick_status1[4] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx5;
				end
				// Brick 6 area & Brick 6 exists
				else if (ball_x + x_change >= Brickx6 && ball_x + x_change < Brickx7 && brick_status1[5] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx6;
				end
				// Brick 7 area & Brick 7 exists
				else if (ball_x + x_change >= Brickx7 && ball_x + x_change < Brickx8 && brick_status1[6] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx7;
				end
				// Brick 8 area & Brick 8 exists
				else if (ball_x + x_change >= Brickx8 && ball_x + x_change < Brickx9 && brick_status1[7] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx8;
				end
				// Brick 9 area & Brick 9 exists
				else if (ball_x + x_change >= Brickx9 && ball_x + x_change < Brickx10 && brick_status1[8] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx9;
				end
				// Brick 10 area & Brick 10 exists
				else if (ball_x + x_change >= Brickx10 && ball_x + x_change < Brickx11 && brick_status1[9] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx10;
				end
				// Brick 11 area & Brick 11 exists
				else if (ball_x + x_change >= Brickx11 && ball_x + x_change < Brickx12 && brick_status1[10] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx11;
				end
				// Brick 12 area & Brick 12 exists
				else if (ball_x + x_change >= Brickx12 && ball_x + x_change < Brickx13 && brick_status1[11] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx12;
				end
				// Brick 13 area & Brick 13 exists
				else if (ball_x + x_change >= Brickx13 && ball_x + x_change < Brickx14 && brick_status1[12] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx13;
				end
				// Brick 14 area & Brick 14 exists
				else if (ball_x + x_change >= Brickx14 && ball_x + x_change < Brickx15 && brick_status1[13] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx14;
				end
				// Brick 15 area & Brick 15 exists
				else if (ball_x + x_change >= Brickx15 && ball_x + x_change < Brickx15 + BrickWidth && brick_status1[14] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx15;
				end
				// Otherwise
				else begin
					brickhit <= 1'b0;
				end
			end
			// Row 2
			else if (ball_y + y_change == Bricky2) begin
				// Brick 1 area & Brick 1 exists
				if (ball_x + x_change >= Brickx1 && ball_x + x_change < Brickx2 && brick_status2[0] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx1;
				end
				// Brick 2 area & Brick 2 exists
				else if (ball_x + x_change >= Brickx2 && ball_x + x_change < Brickx3 && brick_status2[1] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx2;
				end
				// Brick 3 area & Brick 3 exists
				else if (ball_x + x_change >= Brickx3 && ball_x + x_change < Brickx4 && brick_status2[2] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx3;
				end
				// Brick 4 area & Brick 4 exists
				else if (ball_x + x_change >= Brickx4 && ball_x + x_change < Brickx5 && brick_status2[3] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx4;
				end
				// Brick 5 area & Brick 5 exists
				else if (ball_x + x_change >= Brickx5 && ball_x + x_change < Brickx6 && brick_status2[4] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx5;
				end
				// Brick 6 area & Brick 6 exists
				else if (ball_x + x_change >= Brickx6 && ball_x + x_change < Brickx7 && brick_status2[5] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx6;
				end
				// Brick 7 area & Brick 7 exists
				else if (ball_x + x_change >= Brickx7 && ball_x + x_change < Brickx8 && brick_status2[6] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx7;
				end
				// Brick 8 area & Brick 8 exists
				else if (ball_x + x_change >= Brickx8 && ball_x + x_change < Brickx9 && brick_status2[7] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx8;
				end
				// Brick 9 area & Brick 9 exists
				else if (ball_x + x_change >= Brickx9 && ball_x + x_change < Brickx10 && brick_status2[8] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx9;
				end
				// Brick 10 area & Brick 10 exists
				else if (ball_x + x_change >= Brickx10 && ball_x + x_change < Brickx11 && brick_status2[9] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx10;
				end
				// Brick 11 area & Brick 11 exists
				else if (ball_x + x_change >= Brickx11 && ball_x + x_change < Brickx12 && brick_status2[10] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx11;
				end
				// Brick 12 area & Brick 12 exists
				else if (ball_x + x_change >= Brickx12 && ball_x + x_change < Brickx13 && brick_status2[11] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx12;
				end
				// Brick 13 area & Brick 13 exists
				else if (ball_x + x_change >= Brickx13 && ball_x + x_change < Brickx14 && brick_status2[12] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx13;
				end
				// Brick 14 area & Brick 14 exists
				else if (ball_x + x_change >= Brickx14 && ball_x + x_change < Brickx15 && brick_status2[13] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx14;
				end
				// Brick 15 area & Brick 15 exists
				else if (ball_x + x_change >= Brickx15 && ball_x + x_change < Brickx15 + BrickWidth && brick_status2[14] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx15;
				end
				// Otherwise
				else begin
					brickhit <= 1'b0;
				end
			end
			// Row 3
			else if (ball_y + y_change == Bricky3) begin
				// Brick 1 area & Brick 1 exists
				if (ball_x + x_change >= Brickx1 && ball_x + x_change < Brickx2 && brick_status3[0] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx1;
				end
				// Brick 2 area & Brick 2 exists
				else if (ball_x + x_change >= Brickx2 && ball_x + x_change < Brickx3 && brick_status3[1] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx2;
				end
				// Brick 3 area & Brick 3 exists
				else if (ball_x + x_change >= Brickx3 && ball_x + x_change < Brickx4 && brick_status3[2] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx3;
				end
				// Brick 4 area & Brick 4 exists
				else if (ball_x + x_change >= Brickx4 && ball_x + x_change < Brickx5 && brick_status3[3] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx4;
				end
				// Brick 5 area & Brick 5 exists
				else if (ball_x + x_change >= Brickx5 && ball_x + x_change < Brickx6 && brick_status3[4] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx5;
				end
				// Brick 6 area & Brick 6 exists
				else if (ball_x + x_change >= Brickx6 && ball_x + x_change < Brickx7 && brick_status3[5] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx6;
				end
				// Brick 7 area & Brick 7 exists
				else if (ball_x + x_change >= Brickx7 && ball_x + x_change < Brickx8 && brick_status3[6] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx7;
				end
				// Brick 8 area & Brick 8 exists
				else if (ball_x + x_change >= Brickx8 && ball_x + x_change < Brickx9 && brick_status3[7] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx8;
				end
				// Brick 9 area & Brick 9 exists
				else if (ball_x + x_change >= Brickx9 && ball_x + x_change < Brickx10 && brick_status3[8] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx9;
				end
				// Brick 10 area & Brick 10 exists
				else if (ball_x + x_change >= Brickx10 && ball_x + x_change < Brickx11 && brick_status3[9] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx10;
				end
				// Brick 11 area & Brick 11 exists
				else if (ball_x + x_change >= Brickx11 && ball_x + x_change < Brickx12 && brick_status3[10] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx11;
				end
				// Brick 12 area & Brick 12 exists
				else if (ball_x + x_change >= Brickx12 && ball_x + x_change < Brickx13 && brick_status3[11] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx12;
				end
				// Brick 13 area & Brick 13 exists
				else if (ball_x + x_change >= Brickx13 && ball_x + x_change < Brickx14 && brick_status3[12] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx13;
				end
				// Brick 14 area & Brick 14 exists
				else if (ball_x + x_change >= Brickx14 && ball_x + x_change < Brickx15 && brick_status3[13] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx14;
				end
				// Brick 15 area & Brick 15 exists
				else if (ball_x + x_change >= Brickx15 && ball_x + x_change < Brickx15 + BrickWidth && brick_status3[14] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx15;
				end
				// Otherwise
				else begin
					brickhit <= 1'b0;
				end
			end
			// Row 4 (Bottom Row)
			else if (ball_y + y_change == Bricky4) begin
				// Brick 1 area & Brick 1 exists
				if (ball_x + x_change >= Brickx1 && ball_x + x_change < Brickx2 && brick_status4[0] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx1;
				end
				// Brick 2 area & Brick 2 exists
				else if (ball_x + x_change >= Brickx2 && ball_x + x_change < Brickx3 && brick_status4[1] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx2;
				end
				// Brick 3 area & Brick 3 exists
				else if (ball_x + x_change >= Brickx3 && ball_x + x_change < Brickx4 && brick_status4[2] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx3;
				end
				// Brick 4 area & Brick 4 exists
				else if (ball_x + x_change >= Brickx4 && ball_x + x_change < Brickx5 && brick_status4[3] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx4;
				end
				// Brick 5 area & Brick 5 exists
				else if (ball_x + x_change >= Brickx5 && ball_x + x_change < Brickx6 && brick_status4[4] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx5;
				end
				// Brick 6 area & Brick 6 exists
				else if (ball_x + x_change >= Brickx6 && ball_x + x_change < Brickx7 && brick_status4[5] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx6;
				end
				// Brick 7 area & Brick 7 exists
				else if (ball_x + x_change >= Brickx7 && ball_x + x_change < Brickx8 && brick_status4[6] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx7;
				end
				// Brick 8 area & Brick 8 exists
				else if (ball_x + x_change >= Brickx8 && ball_x + x_change < Brickx9 && brick_status4[7] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx8;
				end
				// Brick 9 area & Brick 9 exists
				else if (ball_x + x_change >= Brickx9 && ball_x + x_change < Brickx10 && brick_status4[8] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx9;
				end
				// Brick 10 area & Brick 10 exists
				else if (ball_x + x_change >= Brickx10 && ball_x + x_change < Brickx11 && brick_status4[9] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx10;
				end
				// Brick 11 area & Brick 11 exists
				else if (ball_x + x_change >= Brickx11 && ball_x + x_change < Brickx12 && brick_status4[10] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx11;
				end
				// Brick 12 area & Brick 12 exists
				else if (ball_x + x_change >= Brickx12 && ball_x + x_change < Brickx13 && brick_status4[11] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx12;
				end
				// Brick 13 area & Brick 13 exists
				else if (ball_x + x_change >= Brickx13 && ball_x + x_change < Brickx14 && brick_status4[12] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx13;
				end
				// Brick 14 area & Brick 14 exists
				else if (ball_x + x_change >= Brickx14 && ball_x + x_change < Brickx15 && brick_status4[13] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx14;
				end
				// Brick 15 area & Brick 15 exists
				else if (ball_x + x_change >= Brickx15 && ball_x + x_change < Brickx15 + BrickWidth && brick_status4[14] == 1'b1) begin
					brickhit <= 1'b1;
					hit_x <= Brickx15;
				end
				// Otherwise
				else begin
					brickhit <= 1'b0;
				end
			end
			// change ball direction
			// if hit brick
			if (brickhit == 1'b1) begin
				if (ball_y + y_change == Bricky1)
					hit_y <= Bricky1;
				else if (ball_y + y_change == Bricky2)
					hit_y <= Bricky2;
				else if (ball_y + y_change == Bricky3)
					hit_y <= Bricky3;
				else if (ball_y + y_change == Bricky4)
					hit_y <= Bricky4;
				if (direction == Up)
					direction <= Down;
				else if (direction == Down)
					direction <= Up;
				else if (direction == UpRight)
					direction <= DownRight;
				else if (direction == RightUp)
					direction <= RightDown;
				else if (direction == UpLeft)
					direction <= DownLeft;
				else if (direction == LeftUp)
					direction <= LeftDown;
				else if (direction == DownRight)
					direction <= UpRight;
				else if (direction == RightDown)
					direction <= RightUp;
				else if (direction == DownLeft)
					direction <= UpLeft;
				else if (direction == LeftDown)
					direction <= LeftUp;
			end
			// if not hit brick
			else if (brickhit == 1'b0) begin
				direction <= direction;
				ball_x <= ball_x + x_change;
				ball_y <= ball_y + y_change;
			end
			x <= ball_x;
			y <= ball_y;
		end
		balldone: begin
			// reset finish signals for next use
			ballerasefinish <= 1'b0;
			ballfinish <= 1'b0;
			// disable drawing
			writeEn <= 1'b0;
		end
		initbrick: begin
			// each bit represent the status of each brick
			// 1 is on (existed)
			// 0 is off (not existed)
			brick_status1 <= 15'b111_1111_1111_1111;
			brick_status2 <= 15'b111_1111_1111_1111;
			brick_status3 <= 15'b111_1111_1111_1111;
			brick_status4 <= 15'b111_1111_1111_1111;
			// start brick counter
			brickenable <= 1'b1;
			// draw the 60 bricks
			x <= Brickx1 + brickout[6:0];
			y <= Bricky1 + brickout[13:7];
			colour <= 3'b001;
			if (x >= Brickx1 && x <= Brickx15 + 7'd4 && y >= Bricky1 && y <= Bricky4) begin
			  // Update colour so each brick will have different colours
			  colour <= colour + 1'b1;
			  if (colour == 3'b111 || colour == 3'b000)
					// if current colour is black or white, reset it back to blue
					colour <= 3'b001;
			  // enable drawing when current pixel is in brick area
			  writeEn <= 1'b1;
			end
			else
				// if current pixel is out of area, disable drawing
				writeEn <= 1'b0;
			// Move to next state
			if (brickout[13:7] >= 7'd4)
				brickfinish <= 1'b1;
			end
		erasebrick: begin
				// Set colour to background colour
				colour <= 3'b000;
				// first row (TOP)
				if (hit_y == Bricky1) begin
					hit_y <= Bricky1;
					// first brick (LEFT)
					if (hit_x >= Brickx1 && hit_x < Brickx2) begin
						brick_status1[0] <= 1'b0;
						hit_x <= Brickx1;
					end
					// second brick 
					else if (hit_x >= Brickx2 && hit_x < Brickx3) begin
						brick_status1[1] <= 1'b0;
						hit_x <= Brickx2;
					end
					// third brick 
					else if (hit_x >= Brickx3 && hit_x < Brickx4) begin
						brick_status1[2] <= 1'b0;
						hit_x <= Brickx3;
					end
					// fourth brick 
					else if (hit_x >= Brickx4 && hit_x < Brickx5) begin
						brick_status1[3] <= 1'b0;
						hit_x <= Brickx4;
					end
					// fifth brick 
					else if (hit_x >= Brickx5 && hit_x < Brickx6) begin
						brick_status1[4] <= 1'b0;
						hit_x <= Brickx5;
					end
					// sixth brick 
					else if (hit_x >= Brickx6 && hit_x < Brickx7) begin
						brick_status1[5] <= 1'b0;
						hit_x <= Brickx6;
					end
					// seventh brick 
					else if (hit_x >= Brickx7 && hit_x < Brickx8) begin
						brick_status1[6] <= 1'b0;
						hit_x <= Brickx7;
					end
					// eighth brick 
					else if (hit_x >= Brickx8 && hit_x < Brickx9) begin
						brick_status1[7] <= 1'b0;
						hit_x <= Brickx8;
					end
					// nineth brick 
					else if (hit_x >= Brickx9 && hit_x < Brickx10) begin
						brick_status1[8] <= 1'b0;
						hit_x <= Brickx9;
					end
					// tenth brick 
					else if (hit_x >= Brickx10 && hit_x < Brickx11) begin
						brick_status1[9] <= 1'b0;
						hit_x <= Brickx10;
					end
					// eleventh brick 
					else if (hit_x >= Brickx11 && hit_x < Brickx12) begin
						brick_status1[10] <= 1'b0;
						hit_x <= Brickx11;
					end
					// twelveth brick 
					else if (hit_x >= Brickx12 && hit_x < Brickx13) begin
						brick_status1[11] <= 1'b0;
						hit_x <= Brickx12;
					end
					// thirteen brick 
					else if (hit_x >= Brickx13 && hit_x < Brickx14) begin
						brick_status1[12] <= 1'b0;
						hit_x <= Brickx13;
					end
					// fourteen brick 
					else if (hit_x >= Brickx14 && hit_x < Brickx15) begin
						brick_status1[13] <= 1'b0;
						hit_x <= Brickx14;
					end
					// fifteen brick (RIGHT)
					else if (hit_x >= Brickx15 && hit_x < Brickx15 + BrickWidth) begin
						brick_status1[14] <= 1'b0;
						hit_x <= Brickx15;
					end
				end
				// second row
				else if (hit_y == Bricky2) begin
					hit_y <= Bricky2;
					// first brick (LEFT)
					if (hit_x >= Brickx1 && hit_x < Brickx2) begin
						brick_status2[0] <= 1'b0;
						hit_x <= Brickx1;
					end
					// second brick 
					else if (hit_x >= Brickx2 && hit_x < Brickx3) begin
						brick_status2[1] <= 1'b0;
						hit_x <= Brickx2;
					end
					// third brick 
					else if (hit_x >= Brickx3 && hit_x < Brickx4) begin
						brick_status2[2] <= 1'b0;
						hit_x <= Brickx3;
					end
					// fourth brick 
					else if (hit_x >= Brickx4 && hit_x < Brickx5) begin
						brick_status2[3] <= 1'b0;
						hit_x <= Brickx4;
					end
					// fifth brick 
					else if (hit_x >= Brickx5 && hit_x < Brickx6) begin
						brick_status2[4] <= 1'b0;
						hit_x <= Brickx5;
					end
					// sixth brick 
					else if (hit_x >= Brickx6 && hit_x < Brickx7) begin
						brick_status2[5] <= 1'b0;
						hit_x <= Brickx6;
					end
					// seventh brick 
					else if (hit_x >= Brickx7 && hit_x < Brickx8) begin
						brick_status2[6] <= 1'b0;
						hit_x <= Brickx7;
					end
					// eighth brick 
					else if (hit_x >= Brickx8 && hit_x < Brickx9) begin
						brick_status2[7] <= 1'b0;
						hit_x <= Brickx8;
					end
					// nineth brick 
					else if (hit_x >= Brickx9 && hit_x < Brickx10) begin
						brick_status2[8] <= 1'b0;
						hit_x <= Brickx9;
					end
					// tenth brick 
					else if (hit_x >= Brickx10 && hit_x < Brickx11) begin
						brick_status2[9] <= 1'b0;
						hit_x <= Brickx10;
					end
					// eleventh brick 
					else if (hit_x >= Brickx11 && hit_x < Brickx12) begin
						brick_status2[10] <= 1'b0;
						hit_x <= Brickx11;
					end
					// twelveth brick 
					else if (hit_x >= Brickx12 && hit_x < Brickx13) begin
						brick_status2[11] <= 1'b0;
						hit_x <= Brickx12;
					end
					// thirteen brick 
					else if (hit_x >= Brickx13 && hit_x < Brickx14) begin
						brick_status2[12] <= 1'b0;
						hit_x <= Brickx13;
					end
					// fourteen brick 
					else if (hit_x >= Brickx14 && hit_x < Brickx15) begin
						brick_status2[13] <= 1'b0;
						hit_x <= Brickx14;
					end
					// fifteen brick (RIGHT)
					else if (hit_x >= Brickx15 && hit_x < Brickx15 + BrickWidth) begin
						brick_status2[14] <= 1'b0;
						hit_x <= Brickx15;
					end
				end
				// third row
				else if (hit_y == Bricky3) begin
					hit_y <= Bricky3;
					// first brick (LEFT)
					if (hit_x >= Brickx1 && hit_x < Brickx2) begin
						brick_status3[0] <= 1'b0;
						hit_x <= Brickx1;
					end
					// second brick 
					else if (hit_x >= Brickx2 && hit_x < Brickx3) begin
						brick_status3[1] <= 1'b0;
						hit_x <= Brickx2;
					end
					// third brick 
					else if (hit_x >= Brickx3 && hit_x < Brickx4) begin
						brick_status3[2] <= 1'b0;
						hit_x <= Brickx3;
					end
					// fourth brick 
					else if (hit_x >= Brickx4 && hit_x < Brickx5) begin
						brick_status3[3] <= 1'b0;
						hit_x <= Brickx4;
					end
					// fifth brick 
					else if (hit_x >= Brickx5 && hit_x < Brickx6) begin
						brick_status3[4] <= 1'b0;
						hit_x <= Brickx5;
					end
					// sixth brick 
					else if (hit_x >= Brickx6 && hit_x < Brickx7) begin
						brick_status3[5] <= 1'b0;
						hit_x <= Brickx6;
					end
					// seventh brick 
					else if (hit_x >= Brickx7 && hit_x < Brickx8) begin
						brick_status3[6] <= 1'b0;
						hit_x <= Brickx7;
					end
					// eighth brick 
					else if (hit_x >= Brickx8 && hit_x < Brickx9) begin
						brick_status3[7] <= 1'b0;
						hit_x <= Brickx8;
					end
					// nineth brick 
					else if (hit_x >= Brickx9 && hit_x < Brickx10) begin
						brick_status3[8] <= 1'b0;
						hit_x <= Brickx9;
					end
					// tenth brick 
					else if (hit_x >= Brickx10 && hit_x < Brickx11) begin
						brick_status3[9] <= 1'b0;
						hit_x <= Brickx10;
					end
					// eleventh brick 
					else if (hit_x >= Brickx11 && hit_x < Brickx12) begin
						brick_status3[10] <= 1'b0;
						hit_x <= Brickx11;
					end
					// twelveth brick 
					else if (hit_x >= Brickx12 && hit_x < Brickx13) begin
						brick_status3[11] <= 1'b0;
						hit_x <= Brickx12;
					end
					// thirteen brick 
					else if (hit_x >= Brickx13 && hit_x < Brickx14) begin
						brick_status3[12] <= 1'b0;
						hit_x <= Brickx13;
					end
					// fourteen brick 
					else if (hit_x >= Brickx14 && hit_x < Brickx15) begin
						brick_status3[13] <= 1'b0;
						hit_x <= Brickx14;
					end
					// fifteen brick (RIGHT)
					else if (hit_x >= Brickx15 && hit_x < Brickx15 + BrickWidth) begin
						brick_status3[14] <= 1'b0;
						hit_x <= Brickx15;
					end
				end
				// fourth row (BOTTOM)
				else if (hit_y == Bricky4) begin
					hit_y <= Bricky4;
					// first brick (LEFT)
					if (hit_x >= Brickx1 && hit_x < Brickx2) begin
						brick_status4[0] <= 1'b0;
						hit_x <= Brickx1;
					end
					// second brick 
					else if (hit_x >= Brickx2 && hit_x < Brickx3) begin
						brick_status4[1] <= 1'b0;
						hit_x <= Brickx2;
					end
					// third brick 
					else if (hit_x >= Brickx3 && hit_x < Brickx4) begin
						brick_status4[2] <= 1'b0;
						hit_x <= Brickx3;
					end
					// fourth brick 
					else if (hit_x >= Brickx4 && hit_x < Brickx5) begin
						brick_status4[3] <= 1'b0;
						hit_x <= Brickx4;
					end
					// fifth brick 
					else if (hit_x >= Brickx5 && hit_x < Brickx6) begin
						brick_status4[4] <= 1'b0;
						hit_x <= Brickx5;
					end
					// sixth brick 
					else if (hit_x >= Brickx6 && hit_x < Brickx7) begin
						brick_status4[5] <= 1'b0;
						hit_x <= Brickx6;
					end
					// seventh brick 
					else if (hit_x >= Brickx7 && hit_x < Brickx8) begin
						brick_status4[6] <= 1'b0;
						hit_x <= Brickx7;
					end
					// eighth brick 
					else if (hit_x >= Brickx8 && hit_x < Brickx9) begin
						brick_status4[7] <= 1'b0;
						hit_x <= Brickx8;
					end
					// nineth brick 
					else if (hit_x >= Brickx9 && hit_x < Brickx10) begin
						brick_status4[8] <= 1'b0;
						hit_x <= Brickx9;
					end
					// tenth brick 
					else if (hit_x >= Brickx10 && hit_x < Brickx11) begin
						brick_status4[9] <= 1'b0;
						hit_x <= Brickx10;
					end
					// eleventh brick 
					else if (hit_x >= Brickx11 && hit_x < Brickx12) begin
						brick_status4[10] <= 1'b0;
						hit_x <= Brickx11;
					end
					// twelveth brick 
					else if (hit_x >= Brickx12 && hit_x < Brickx13) begin
						brick_status4[11] <= 1'b0;
						hit_x <= Brickx12;
					end
					// thirteen brick 
					else if (hit_x >= Brickx13 && hit_x < Brickx14) begin
						brick_status4[12] <= 1'b0;
						hit_x <= Brickx13;
					end
					// fourteen brick 
					else if (hit_x >= Brickx14 && hit_x < Brickx15) begin
						brick_status4[13] <= 1'b0;
						hit_x <= Brickx14;
					end
					// fifteen brick (RIGHT)
					else if (hit_x >= Brickx15 && hit_x < Brickx15 + BrickWidth) begin
						brick_status4[14] <= 1'b0;
						hit_x <= Brickx15;
					end
				end
				// Overdraw the brick
				x <= hit_x + singlebrickout;
				y <= hit_y;
				if (x >= hit_x && x < hit_x + BrickWidth)
					writeEn <= 1'b1;
				else
					writeEn <= 1'b0;
				if (singlebrickout > 3'd4)
					brickerasefinish <= 1'b1;
		end
		brickdone: begin
			brickenable <= 1'b0;
			brickfinish <= 1'b0;
			writeEn <= 1'b0;
		end
		update: begin
			if (brick_status1 == 15'd0 &&
				brick_status2 == 15'd0 &&
				brick_status3 == 15'd0 &&
				brick_status4 == 15'd0) begin
				gameover <= 1'b1;
			end
			else	
				gameover <= 1'b0;
		end
		reset: begin
			// enable reset counter
			resetenable <= 1'b1;
			// enable drawing
			writeEn <= 1'b1;
			// change colour to background colour
			colour <= 3'b000;
			// erase the entire monitor
			x <= 7'd0 + resetout[6:0];
			y <= 7'd0 + resetout[13:7];
			// if counter finish, go to next state
			if (resetout == 14'b11_1111_1111_1111)
				resetfinish <= 1'b1;
		end
		resetdone: begin
			// reset finish signal
			resetfinish <= 1'b0;
			// reset finish counter
			resetenable <= 1'b0;
		end
		default: begin
			// initialize all the finish signals
			ballerasefinish <= 1'b0;
			ballfinish <= 1'b0;
			brickerasefinish <= 1'b0;
			brickfinish <= 1'b0;
			brickhit <= 1'b0;
			// set colour to background colour to ensure nothing is draw
			colour <= 3'b000;
			gameover <= 1'b0;
			paddleerasefinish <= 1'b0;
			paddlefinish <= 1'b0;
			resetfinish <= 1'b0;
			wallfinish <= 1'b0;
			// disable drawing
			writeEn <= 1'b0;
		end
		endcase
	end

	// Determine the movement based on direction
	always@(posedge clock) begin
		case (direction)
			Up: begin // Up 1 pixel
				y_change <= -7'd1;
				x_change <= 7'd0;
			end
			UpRight: begin // Up 1 pixel, Right 1 pixel
				y_change <= -7'd1;
				x_change <= 7'd1;
			end
			RightUp: begin // Up 1 pixel, Right 2 pixels
				y_change <= -7'd1;
				x_change <= 7'd2;
			end
			UpLeft:	begin // Up 1 pixel, Left 1 pixel
				y_change <= -7'd1;
				x_change <= -7'd1;
			end
			LeftUp: begin // Up 1 pixel, Left 2 pixels
				y_change <= -7'd1;
				x_change <= -7'd2;
			end
			Down: begin // Down 1 pixel
				y_change <= 7'd1;
				x_change <= 7'd0;
			end
			DownRight: begin // Down 1 pixel, Right 1 pixel
				y_change <= 7'd1;
				x_change <= 7'd1;
			end
			RightDown: begin // Down 1 pixel, Right 2 pixel
				y_change <= 7'd1;
				x_change <= 7'd2;
			end
			DownLeft: begin // Down 1 pixel, Left 1 pixel
				y_change <= 7'd1;
				x_change <= -7'd1;
			end
			LeftDown: begin // Down 1 pixel, Left 2 pixel
				y_change <= 7'd1;
				x_change <= -7'd2;
			end
		endcase
	end	
endmodule

// Wall Counter
module wallcounter (
	input clock,
	input wallenable,
	output reg [13:0] wallout);

	always@(posedge clock) begin
		if (wallout[6:0] == 7'd118 && wallenable == 1'b1) begin
			wallout[6:0] <= 7'd0;
			wallout[13:7] <= wallout[13:7] + 1'b1;
		end
		else if (wallenable == 1'b1)
			wallout <= wallout + 1'b1;
		else 
			wallout <= 7'd0;
	end
endmodule

// Paddle Counter
module paddlecounter(
	input clock,
	input paddleenable,
	output reg [2:0] paddleout);
	
	always@(posedge clock) begin
		if (paddleenable == 1'b1) begin
			paddleout <= paddleout + 1'b1;
		end
		else 
			paddleout <= 3'd0;
	end
endmodule

// 50MHz to 60Hz Rate Divider
module MovePerSecond (
	input clock,
	output reg [25:0] secondpulse);
	
	always@(posedge clock) begin
		if (secondpulse <= 26'd833333)
			secondpulse <= 26'd0;
		else
			secondpulse <= secondpulse + 1'b1;
	end
endmodule

// Reset Counter
module resetcounter(
	input clock,
	input resetenable,
	output reg [13:0] resetout);
	
	always@(posedge clock) begin
		if (resetenable == 1'b0)
			resetout <= 14'b0;
		else begin
			resetout <= resetout + 1'b1;
		end
	end
endmodule

// Brick Counter
module brickcounter(
	input clock,
  input brickenable,
  output reg [13:0] brickout);
	
  always@(posedge clock) begin
 		if (brickenable == 1'b0)
   		brickout <= 14'b0;
  	else begin
    	if (brickout[6:0] == 7'd75) begin
      	brickout[6:0] <= 7'd0;
        brickout[13:7] <= brickout[13:7] + 1'b1;
      end
      else 
      	brickout <= brickout + 1'b1;
    end
  end
endmodule

module singlebrickcounter(
	input clock,
	input brickenable,
	output reg [2:0] singlebrickout);
	
	always@(posedge clock) begin
		if (brickenable == 1'b1) begin
			singlebrickout <= singlebrickout + 1'b1;
		end
		else 
			singlebrickout <= 3'd0;
	end
endmodule