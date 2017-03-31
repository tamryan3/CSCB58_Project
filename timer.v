`timescale 1ns / 1ns

module timer (
	input CLOCK_50,
	input [17:0] SW,
	output [6:0] HEX7, HEX6, HEX5, HEX4
	);
	wire reset;
	assign reset = SW[17];
	wire enable;
	wire [25:0] RD_out;
	wire [3:0] mt, mo, st, so;
	
	RateDivider RD (
		.clock(CLOCK_50),
		.reset(SW[17]),
		.pulse(RD_out)
	);
	
	assign enable = (RD_out == 26'd49999999) ? 1'b1 : 1'b0;
	
	DisplayCounter DC (
		.clock(CLOCK_50),
		.enable(enable),
		.reset(reset),
		.mt(mt),
		.mo(mo),
		.st(st),
		.so(so)
	);
	
	hex_display hx7 (.IN(mt), .OUT(HEX7));
	hex_display hx6 (.IN(mo), .OUT(HEX6));
	hex_display hx5 (.IN(st), .OUT(HEX5));
	hex_display hx4 (.IN(so), .OUT(HEX4));
	
endmodule

module RateDivider (
	input clock,
	input reset,
	output reg [25:0] pulse
	);
	
	always@(posedge clock) begin
		if (reset == 1'b1) begin
			pulse <= 26'd0;
		end
		else if (pulse == 26'd49999999) begin
			pulse <= 26'd0;
		end
		else begin
			pulse <= pulse + 1'b1;
		end
	end	
endmodule

/*
 * Count Down Timer
 */
module DisplayCounter(
		input clock,
		input enable,
		input reset,
		output reg [3:0] mt, mo, st, so
	);
	always@(posedge clock) begin
		if (reset == 1'b1) begin
			mt <= 4'b0;
			mo <= 4'b0;
			st <= 4'b0;
			so <= 4'b0;
		end
		else if (enable == 1'b1) begin
			if (so == 4'b1001) begin
				so <= 4'b0000;
				if (st == 4'b0101) begin
					st <= 4'b0000;
					if (mo == 4'b0010) begin
						so <= 4'b0;
						mt <= 4'b0;
						mo <= 4'b0010;
						st <= 4'b0;
					end
					else if (mo < 4'b0010)
						mo <= mo + 1'b1;
				end
				else if (mo < 4'b0010)
					st <= st + 1'b1;
			end
			else if (mo < 4'b0010)
				so <= so + 1'b1;
		end
	end
endmodule


/* Count up Counter
 *
	end
*/

module hex_display(IN, OUT);
    input [3:0] IN;
	output reg [7:0] OUT;
	 
	always @(*)
	begin
		case(IN[3:0])
			4'b0000: OUT = 7'b1000000;
			4'b0001: OUT = 7'b1111001;
			4'b0010: OUT = 7'b0100100;
			4'b0011: OUT = 7'b0110000;
			4'b0100: OUT = 7'b0011001;
			4'b0101: OUT = 7'b0010010;
			4'b0110: OUT = 7'b0000010;
			4'b0111: OUT = 7'b1111000;
			4'b1000: OUT = 7'b0000000;
			4'b1001: OUT = 7'b0011000;
			default: OUT = 7'b1000000;
		endcase
	end
endmodule
