// CONTROLLER MODULE
/*************************************************************/
// 
// outputSelect is default 0 (result of the ALU)
// outputSelect = 01 (result of shifter [SHIFT])
// outputSelect = 10 (copies either RSrc or Immd [COPY])
// outputSelect = 11 (reads from memory [LOAD])
//
// FETCH - retrieveInstruction, pcContinue
// IF DOES NOT WORK, DO THIS
// FETCH1 - retrieveInstruction, LOAD
// FETCH2 - retrieveInstruction, pcContinue
//
// After the instruction is updated...
//
// DECODE - Look at OP CODE
// OP CODE
// 0000 - Look at EXTENDED OP CODE
// 0001 - ANDI -> WRITETOREG
// 0010 - ORI -> WRITETOREG
// 0011 - XORI -> WRITETOREG
// 0100 - Look at EXTENDED OP CODE
// 0101 - ADDI -> WRITEANDSETFLAGS
// 1000 - Look at SHIFTS
// 1001 - SUBI -> [Check OPCODE[1]] -> WRITEANDSETFLAGS
// 1011 - SUBI -> [Check OPCODE[1]] -> ONLYSETFLAGS (CMPI)
// 1100 - [Check Conditions] -> BRANCH -> WRITETOPC
// 1101 - MOVI -> WRITETOREG
// 1111 - LUI -> MEMLOAD -> WRITETOREG
// EXTENDED OP CODE
// 0000 - MOV -> [Check OPCODE[2]] -> MEMLOAD -> WRITETOREG (LOAD)
// 0001 - AND -> WRITETOREG
// 0010 - OR -> WRITETOREG
// 0011 - XOR -> WRITETOREG
// 0100 - MOV -> [Check OPCODE[2]] -> WRITETOMEM (STOR)
// 0101 - ADD -> WRITEANDSETFLAGS
// 1000 - JAL -> (MOV -> WRITETOPC) (JUMP)
// 1001 - SUB -> [Check OPCODE[1]] -> WRITEANDSETFLAGS
// 1011 - SUB -> [Check OPCODE[1]] -> ONLYSETFLAGS (CMP)
// 1100 - [Check Conditions] -> MOV -> WRITETOPC (JUMP)
// 1101 - MOV -> WRITETOREG
// SHIFTS
// 000s - SHFTI -> WRITETOREG (LSHI)
// 001s - SHFTI -> WRITETOREG (ASHUI)
// 0100 - SHFT -> WRITETOREG (LSH)
// 0110 - SHFT -> WRITETOREG (ASHU)
// SPECIAL
//
// [AT THE END OF EACH CHAIN, GO BACK TO FETCH (-> FETCH)]
// 
// SIMPLIFIED STATES
//
// ADD - rTypeInstruction, 000
// ADDI - 000
// MUL - rTypeInstruction, 111
// MULI - 111
// |
// v
// WRITEANDSETFLAGS - regWrite, flagSet
//
// SUB - rTypeInstruction, 100
// SUBI - 100
// | OPCODE[1] == 0
// v
// WRITEANDSETFLAGS - regWrite, flagSet
// | OPCODE[1] == 1
// v
// ONLYSETFLAGS - flagSet (CMP and CMPI)
//
// AND - rTypeInstruction, 001
// ANDI - zeroExtend, 001
// OR - rTypeInstruction, 010
// ORI - zeroExtend, 010
// XOR - rTypeInstruction, 011
// XORI - zeroExtend, 011
// MOV - rTypeInstruction, COPY
// MOVI - zeroExtend, COPY
// SHFT - rTypeInstruction, SHIFT, zeroExtend = !EXTENDEDOPCODE[1]
// SHFTI - SHIFT, zeroExtend = !EXTENDEDOPCODE[1]
// |
// v
// WRITETOREG - regWrite
//
// LUI - luiInstruction, SHIFT
// |
// v
// WRITETOREG - regWrite
//
// (LOAD)
// MOV - rTypeInstruction, COPY
// | OPCODE[2] == 0
// v
// MEMLOAD - LOAD
// |
// v
// WRITETOREG - regWrite
// 
// (STOR)
// MOV - rTypeInstruction, COPY
// | OPCODE[2] == 1
// v
// WRITETOMEM - memWrite
//
// [These next two instructions must have passed condition checks before executing]
// (JUMP)
// MOV - rTypeInstruction, COPY
// | OPCODE[3] == 1
// v
// WRITETOPC - pcOverwrite
//
// BRANCH - pcInstruction, 000
// |
// v
// WRITETOPC - pcOverwrite
//
// (JAL)
// JAL - storeNextInstruction, regWrite
// |
// v
// (JUMP)
// 
// [At the end of each instruction chain, go back to FETCH]
module controller(input clk, reset,
                  input [3:0] firstOp,
		  input [3:0] condition,
                  input [3:0] extendedOp,
                  input [4:0] flags,
                  output reg [2:0] aluOp,
                  output reg [1:0] outputSelect,
                  output reg regWrite, memWrite, luiInstruction, retrieveInstruction,
                             zeroExtend, pcContinue, pcOverwrite, flagSet, rTypeInstruction,
                             pcInstruction, storeNextInstruction, loadPC);
    
    // Parameters for states.
    parameter   FETCH1           = 5'b00000;
    parameter   FETCH2           = 5'b11111;
    parameter   DECODE           = 5'b00001;
    // parameter   SPECIALDECODE    = 5'b00010;
    // parameter   CONDITIONCHECK   = 5'b00011;
    // parameter   PASSCONDITION    = 5'b00100;
    parameter   ADD              = 5'b00101;
    parameter   ADDI             = 5'b00110;
    parameter   SUB              = 5'b00111;
    parameter   SUBI             = 5'b01000;
    parameter   AND              = 5'b01001;
    parameter   ANDI             = 5'b01010;
    parameter   OR               = 5'b01011;
    parameter   ORI              = 5'b01100;
    parameter   XOR              = 5'b01101;
    parameter   XORI             = 5'b01110;
    parameter   MOVI             = 5'b01111;
    parameter   SHFT             = 5'b10000;
    parameter   SHFTI            = 5'b10001;
    parameter   MOV              = 5'b10010;
    parameter   LUI              = 5'b10011;
    parameter   MEMLOAD          = 5'b10100;
    parameter   BRANCH           = 5'b10101;
    parameter   JAL              = 5'b10110;
    // parameter   JUMP             = 5'b10111;
    parameter   WRITEANDSETFLAGS = 5'b11000;
    parameter   ONLYSETFLAGS     = 5'b11001;
    parameter   WRITETOREG       = 5'b11010;
    parameter   WRITETOMEM       = 5'b11011;
    parameter   WRITETOPC        = 5'b11100;
    parameter   MUL              = 5'b11101;
    parameter   MULI             = 5'b11110;

    // Parameters for condition codes
    parameter EQ    = 4'b0000;
    parameter NE    = 4'b0001;
    parameter CS    = 4'b0010;
    parameter CC    = 4'b0011;
    parameter HI    = 4'b0100;
    parameter LS    = 4'b0101;
    parameter GT    = 4'b0110;
    parameter LE    = 4'b0111;
    parameter FS    = 4'b1000;
    parameter FC    = 4'b1001;
    parameter LO    = 4'b1010;
    parameter HS    = 4'b1011;
    parameter LT    = 4'b1100;
    parameter GE    = 4'b1101;
    parameter UC    = 4'b1110;
    parameter NJ    = 4'b1111;

    reg [4:0] state, nextstate; 

    // Assign flag bits for checking
    wire negative, zero, flag, low, carry;
    assign negative = flags[4];
    assign zero = flags[3];
    assign flag = flags[2];
    assign low = flags[1];
    assign carry = flags[0];

    // state register
    always @(posedge clk)
      if(~reset) state <= FETCH1;
      else state <= nextstate;

    // Functions for decoding
    // This function will check the extended op code
    function [4:0] specialDecode(input [3:0] extendedOpCode);
        case(extendedOpCode)
            4'b0000: specialDecode = MOV; // LOAD
            4'b0001: specialDecode = AND;
            4'b0010: specialDecode = OR;
            4'b0011: specialDecode = XOR;
            4'b0100: specialDecode = MOV; // STOR
            4'b0101: specialDecode = ADD;
            4'b1000: specialDecode = JAL;
            4'b1001: specialDecode = SUB;
            4'b1011: specialDecode = SUB;
            4'b1100: specialDecode = conditionCheck(condition);
            4'b1101: specialDecode = MOV;
            4'b1110: specialDecode = MUL;
            default: specialDecode = FETCH1; // should never happen
        endcase
    endfunction

    // This function will check the condition code
    function [4:0] conditionCheck(input [3:0] cond);
        case(cond)
            EQ: begin
                    if (zero) // EQUAL (EQ)
                        conditionCheck = passCondition(firstOp[3]);
                    else
                        conditionCheck = FETCH1;
                end
            NE: begin
                    if (!zero) // NOT EQUAL (NE)
                        conditionCheck = passCondition(firstOp[3]);
                    else
                        conditionCheck = FETCH1;
                end
            CS: begin
                    if (carry) // CARRY SET (CS)
                        conditionCheck = passCondition(firstOp[3]);
                    else
                        conditionCheck = FETCH1;
                end
            CC: begin
                    if (!carry) // CARRY CLEAR (CC)
                        conditionCheck = passCondition(firstOp[3]);
                    else
                        conditionCheck = FETCH1;
                end
            HI: begin
                    if (!low && !zero) // HIGHER THAN (HI)
                        conditionCheck = passCondition(firstOp[3]);
                    else
                        conditionCheck = FETCH1;
                end
            LS: begin
                    if (low || zero) // LOWER THAN OR SAME AS (LS)
                        conditionCheck = passCondition(firstOp[3]);
                    else
                        conditionCheck = FETCH1;
                end
            GT: begin
                    if (!negative && !zero) // GREATER THAN (GT)
                        conditionCheck = passCondition(firstOp[3]);
                    else
                        conditionCheck = FETCH1;
                end
            LE: begin
                    if (negative || zero) // LESS THAN OR EQUAL (LE)
                        conditionCheck = passCondition(firstOp[3]);
                    else
                        conditionCheck = FETCH1;
                end
            FS: begin
                    if (flag) // FLAG SET (FS)
                        conditionCheck = passCondition(firstOp[3]);
                    else
                        conditionCheck = FETCH1;
                end
            FC: begin
                    if (!flag) // FLAG CLEAR (FC)
                        conditionCheck = passCondition(firstOp[3]);
                    else
                        conditionCheck = FETCH1;
                end
            LO: begin
                    if (low) // LOWER THAN (LO)
                        conditionCheck = passCondition(firstOp[3]);
                    else
                        conditionCheck = FETCH1;
                end
            HS: begin
                    if (!low) // HIGHER THAN OR SAME AS (HS)
                        conditionCheck = passCondition(firstOp[3]);
                    else
                        conditionCheck = FETCH1;
                end
            LT: begin
                    if (negative) // LESS THAN (LT)
                        conditionCheck = passCondition(firstOp[3]);
                    else
                        conditionCheck = FETCH1;
                end
            GE: begin
                    if (!negative) // GREATER THAN OR EQUAL (GE)
                        conditionCheck = passCondition(firstOp[3]);
                    else
                        conditionCheck = FETCH1;
                end
            UC: conditionCheck = passCondition(firstOp[3]); // UNCONDITIONAL (UC)
            NJ: conditionCheck = FETCH1; // NEVER JUMP ()
            default: conditionCheck = FETCH1; // should never happen
        endcase
    endfunction

    // This function will decide a branch or jump
    function [4:0] passCondition(input startBranch);
        if (startBranch) passCondition = BRANCH;
        else passCondition = MOV; // Jump
    endfunction       

    // next state logic (combinational)
    always @(*)
      begin
         case(state)
            FETCH1:  nextstate <= FETCH2;
            FETCH2:  nextstate <= DECODE;
            DECODE:  case(firstOp)
                        4'b0000: nextstate <= specialDecode(extendedOp); // R-Type Instructions
                        4'b0001: nextstate <= ANDI;
                        4'b0010: nextstate <= ORI;
                        4'b0011: nextstate <= XORI;
						4'b0100: nextstate <= specialDecode(extendedOp); // Special Instructions
                        4'b0101: nextstate <= ADDI;
                        4'b1000: begin
                                if (extendedOp[2]) nextstate <= SHFT; // LSH, ASHU
                                else nextstate <= SHFTI; // LSHI, ASHUI 
                            end
                        4'b1001: nextstate <= SUBI;
                        4'b1011: nextstate <= SUBI;
                        4'b1100: nextstate <= conditionCheck(condition);
                        4'b1101: nextstate <= MOVI;
                        4'b1110: nextstate <= MULI;
                        4'b1111: nextstate <= LUI;
                        default: nextstate <= FETCH1; // should never happen
                     endcase
            ADD: nextstate <= WRITEANDSETFLAGS;
            ADDI: nextstate <= WRITEANDSETFLAGS;
            SUB: begin
                    if (extendedOp[1]) nextstate <= ONLYSETFLAGS; // CMP
                    else nextstate <= WRITEANDSETFLAGS; // SUB
                end
            SUBI: begin
                    if (firstOp[1]) nextstate <= ONLYSETFLAGS; // CMPI
                    else nextstate <= WRITEANDSETFLAGS; // SUBI
                end
            AND: nextstate <= WRITETOREG;
            ANDI: nextstate <= WRITETOREG;
            OR: nextstate <= WRITETOREG;
            ORI: nextstate <= WRITETOREG;
            XOR: nextstate <= WRITETOREG;
            XORI: nextstate <= WRITETOREG;
            MUL: nextstate <= WRITETOREG;
            MULI: nextstate <= WRITETOREG;
            MOVI: nextstate <= WRITETOREG;
            SHFT: nextstate <= WRITETOREG;
            SHFTI: nextstate <= WRITETOREG;
            MOV: begin
                    if (firstOp == 4'b0000) nextstate <= WRITETOREG; // MOV
                    else begin
                        if (extendedOp[3]) nextstate <= WRITETOPC; // JUMP
                        else if (extendedOp[2]) nextstate <= WRITETOMEM; // STOR
                        else nextstate <= MEMLOAD; // LOAD
                    end
                end
            LUI: nextstate <= WRITETOREG;
            MEMLOAD: nextstate <= WRITETOREG;
            BRANCH: nextstate <= WRITETOPC;
            JAL: nextstate <= MOV; // Performs a jump
            WRITEANDSETFLAGS: nextstate <= FETCH1;
            ONLYSETFLAGS: nextstate <= FETCH1;
            WRITETOREG: nextstate <= FETCH1;
            WRITETOMEM: nextstate <= FETCH1;
            WRITETOPC: nextstate <= FETCH1;
            default: nextstate <= FETCH1; // should never happen
         endcase
      end

    // This combinational block generates the outputs from each state. 
    always @(*) begin
         // Set all outputs to 0.
	  aluOp                <= 3'b000;
	  outputSelect         <= 2'b00;
	  regWrite             <= 0;
	  memWrite             <= 0;
	  luiInstruction       <= 0;
	  retrieveInstruction  <= 0;
	  zeroExtend           <= 0;
	  pcContinue           <= 0;
	  pcOverwrite          <= 0;
	  flagSet              <= 0;
	  rTypeInstruction     <= 0;
	  pcInstruction        <= 0;
	  storeNextInstruction <= 0;
      loadPC               <= 0;
	  // Based on state, set outputs.
          case (state)
		FETCH1: begin
				loadPC <= 1;
				outputSelect <= 2'b11; //LOAD				
			end
        FETCH2: begin
                loadPC <= 1;
                retrieveInstruction <= 1;
                pcContinue <= 1;
            end
		DECODE: begin
				// No flags - does nothing
			end
		ADD: begin
				rTypeInstruction <= 1;
				aluOp <= 3'b000;
			end
		ADDI: begin
				aluOp <= 3'b000;
			end
		SUB: begin
				rTypeInstruction <= 1;
				aluOp <= 3'b100;
			end
		SUBI: begin
				aluOp <= 3'b100;
			end
		AND: begin
				rTypeInstruction <= 1;
				aluOp <= 3'b001;
			end
		ANDI: begin
				zeroExtend <= 1;
				aluOp <= 3'b001;
			end
		OR: begin
				rTypeInstruction <= 1;
				aluOp <= 3'b010;
			end
		ORI: begin
				zeroExtend <= 1;
				aluOp <= 3'b010;
			end
		XOR: begin
				rTypeInstruction <= 1;
				aluOp <= 3'b011;
			end
		XORI: begin
				zeroExtend <= 1;
				aluOp <= 3'b011;
			end
        MUL: begin
                rTypeInstruction <= 1;
                aluOp <= 3'b111;
            end
        MULI: begin
                aluOp <= 3'b111;
            end
		MOVI: begin
				zeroExtend <= 1;
				outputSelect <= 2'b10; //COPY
			end
		SHFT: begin
				rTypeInstruction <= 1;
                zeroExtend <= !extendedOp[1]; // LSH = 1, ASHU = 0
				outputSelect <= 2'b01; //SHIFT
			end
		SHFTI: begin
                zeroExtend <= !extendedOp[1]; // LSHI = 1, ASHU = 0
				outputSelect <= 2'b01; //SHIFT					
			end
		MOV: begin
				rTypeInstruction <= 1;
				outputSelect <= 2'b10; //COPY
			end
		LUI: begin
				luiInstruction <= 1;
				outputSelect <= 2'b01; //SHIFT
			end
		MEMLOAD: begin
				outputSelect <= 2'b11; //LOAD
			end
		BRANCH: begin
				pcInstruction <= 1;
			end
		JAL: begin
				storeNextInstruction <= 1;
				regWrite <= 1;
			end
		WRITEANDSETFLAGS: begin
				regWrite <= 1;
				flagSet <= 1;
			end
		ONLYSETFLAGS: begin
				flagSet <= 1; //CMP and CMPI
			end
		WRITETOREG: begin
				regWrite <= 1;
			end
		WRITETOMEM: begin
				memWrite <= 1;
			end
		WRITETOPC: begin
				pcOverwrite <= 1;
			end		
		default: begin
			// does nothing
			end
      endcase
    end

endmodule 
