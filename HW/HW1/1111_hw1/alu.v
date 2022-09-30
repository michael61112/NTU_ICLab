module alu #(
	parameter INT_W =3,
	parameter FRAC_W = 5,
	parameter INST_W = 3,
	parameter DATA_W = INT_W + FRAC_W
)(
	input 				i_clk,
	input 				i_rst_n,
	input				i_valid,
	input signed	[DATA_W-1:0]	i_data_a,
	input signed	[DATA_W-1:0]	i_data_b,
	input		[INST_W-1:0]	i_inst,
	output				o_valid,
	output		[DATA_W-1:0] 	o_data
);
localparam ADD = 3'b000;
localparam SUB = 3'b001;
localparam MULTI = 3'b010;
localparam NAND = 3'b011;
localparam XNOR = 3'b100;
localparam SIGMOID = 3'b101;
localparam R_CIRCULAR_SHIFT = 3'b110;
localparam MIN = 3'b111;
localparam ROUND_DOWN = 1'b0;
localparam ROUND = 1'b1;
// ----------------------------------------
// Wires and Registers
// ----------------------------------------
reg [DATA_W:0]	o_data_w, o_data_r;
reg	   	o_valid_w, o_valid_r;

// ----------------------------------------
// Continuous Assignment
// ----------------------------------------
assign o_valid = o_valid_r;
assign o_data = o_data_r;

// ----------------------------------------
// Combinational Blocks
// ----------------------------------------
always@(*) begin
	if(i_valid) begin
		o_data_w = o_data_r;
		case(i_inst)
			ADD: 
				o_data_w = arithmetic(i_data_a, i_data_b, ADD);
			SUB: 
				o_data_w = arithmetic(i_data_a, i_data_b, SUB);
			MULTI: 
				o_data_w = multi(i_data_a, i_data_b, ROUND);
			NAND: 
				o_data_w = ~(i_data_a & i_data_b);
			XNOR:
				o_data_w = ~(i_data_a ^ i_data_b);
			SIGMOID: 
				o_data_w = sigmoid(i_data_a);
			R_CIRCULAR_SHIFT: 
				o_data_w = rotate_R(i_data_a, i_data_b);
			MIN: 
				o_data_w = (i_data_a < i_data_b) ? i_data_a : i_data_b;
		endcase
		o_valid_w = 1'b1;
	end
	else
		o_valid_w = 1'b0;
end
// ----------------------------------------
// Sequential Blocks
// ----------------------------------------
always@(posedge i_clk or negedge i_rst_n) begin
	if(!i_rst_n) begin
		o_data_r <= 0;
		o_valid_r <= 0;
	end else begin
		o_data_r <= o_data_w;
		o_valid_r <= o_valid_w;
	end
end
// ----------------------------------------
// Fuction
// ----------------------------------------
function [DATA_W-1:0] arithmetic;
	input signed [DATA_W-1:0] 	i_data_a, i_data_b;
	input 				minus;
	reg   	     [DATA_W:0]		temp;
	begin
		if (minus)
			temp = i_data_a - i_data_b;
		else
			temp = i_data_a + i_data_b;

		arithmetic = (temp[DATA_W:DATA_W-1] == 2'b00 || temp[DATA_W:DATA_W-1] == 2'b11) ? temp[DATA_W-1:0] : {temp[DATA_W],{(DATA_W-1){!temp[DATA_W]}}};
	end
endfunction

function [DATA_W-1:0] multi;
	input signed [DATA_W-1:0] 	i_data_a, i_data_b;
	input 				round;
	reg				carry;
	reg   signed [2*DATA_W-1:0] 	result; 


	begin
		result = i_data_a * i_data_b;

		if (round) begin
			carry = result[DATA_W*2-1] ? (result[FRAC_W-1] & (|result[FRAC_W-2:0])) : result[FRAC_W-1];
			multi = (result[(DATA_W*2-2):(DATA_W*2-3)] == 2'b00 || result[(DATA_W*2-2):(DATA_W*2-3)] == 2'b11) ? 
				result[DATA_W+FRAC_W-1:FRAC_W] + carry : {result[DATA_W*2-1],{(DATA_W-1){!result[DATA_W*2-1]}}};
		end
		else
			multi = (result[(DATA_W*2-2):(DATA_W*2-3)] == 2'b00 || result[(DATA_W*2-2):(DATA_W*2-3)] == 2'b11) ? 
				result[DATA_W+FRAC_W-1:FRAC_W]  : {result[15],{(DATA_W-1){!result[15]}}};
	end
endfunction



function [DATA_W-1:0] sigmoid;
	input signed [DATA_W-1:0]  	i_data_a;
	
	begin
		if (!i_data_a[DATA_W-1] && i_data_a >= 8'b01000000)
			sigmoid = 8'b00100000;
		else if (i_data_a[DATA_W-1] && (i_data_a[DATA_W-2:0] <= 7'b1000000))
			sigmoid = 8'b00000000;
		else
			sigmoid = multi(8'b00001000 , (i_data_a-8'b11000000), ROUND_DOWN);
	end
endfunction

function [DATA_W-1:0] rotate_R;
	input 	[DATA_W-1:0] 	i_data_a, i_data_b;
	reg 	[2:0] 		shift;

	begin
		shift = i_data_b[2:0];
		rotate_R = ({i_data_a, i_data_a} >> shift);
	end
endfunction


endmodule

