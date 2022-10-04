// ALU MODULE
/*************************************************************/
// A 16-bit two's complement ALU that will take two registers
// as arguments and output a 16-bit result.
//
//	Must support all required instructions:
/*
	ADD
	ADDI
	
	SUB
	SUBI
	
	CMP
	CMPI
	
	AND
	ANDI
	
	OR
	ORI
	
	XOR
	XORI
	
	MOV
	MOVI
	
	LSH
	LSHI
	
	LUI
	LOAD
	STOR
	
	Bcond
	Jcond
	JAL
*/
//
// The ALU also must generate condition flags:
/*
	C - Carry bit (1 if carry UNSIGNED)
	L - Low bit (1 if Rdest < Rsc UNSIGNED)
	F - Flag bit (1 if overflow SIGNED)
	Z - Zero bit (1 if Rdest = Rsc ALWAYS)
	N - Negative bit (1 if Rdest < Rsc SIGNED)
*/
module ALU #(parameter WIDTH = 16) (regSrc, regDst, aluOp, aluResult, carry, low, flag, zero, negative);
	input [WIDTH - 1:0] regSrc, regDst; // Register values to perform arithmetic on
	input[2:0] aluOp; // Operation code (MSB determines add/sub, [1:0] determines operation)
	output reg [WIDTH - 1:0] aluResult; // Result of ALU
	output carry, low, flag, zero, negative;

	wire [WIDTH - 1:0] regSrc2, sum;
	wire addOverflow, subOverflow;

	// Sum will be the result of an add or subtract based on the operation code
	assign regSrc2 = aluOp[2] ? ~regSrc:regSrc; 
	assign sum = regDst + regSrc2 + aluOp[2];

	// NEED TO FIGURE OUT:
	// What is default comparison (signed or unsigned) and how can we compare without operators
	// When does a carry bit need to be set to 1
	// How can we determine signed overflow
	assign carry = 1'b0; // NEED TO BE COMPLETED
	assign zero = aluResult == 0;
	assign low = 1'b0; // NEED TO BE COMPLETED
	assign flag = 1'b0; // NEED TO BE COMPLETED
	assign negative = 1'b0; // NEED TO BE COMPLETED

	always@(*) begin
		case(aluOp[1:0])
			2'b00: aluResult <= sum; // Add/Sub
			2'b01: aluResult <= regDst & regSrc; // Logical And
			2'b10: aluResult <= regDst | regSrc; // Logical Or
			2'b11: aluResult <= regDst ^ regSrc; // Logical Xor
		endcase
	end

endmodule
