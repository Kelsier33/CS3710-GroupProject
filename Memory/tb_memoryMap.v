// TESTBENCH FOR memoryMap FILE
/*************************************************************/
`timescale 1ns / 1ps

module tb_memoryMap #(parameter DATA_WIDTH=16, parameter ADDR_WIDTH=16) ();

  reg [(DATA_WIDTH-1):0] data_a, data_b;
  reg [(ADDR_WIDTH-1):0] addr_a, addr_b;
  reg write_a, write_b, clk;
  reg [(ADDR_WIDTH-1):0] InputData;
  wire [(DATA_WIDTH-1):0] OutputDataA, OutputDataB;
  integer i;

  // Instantiate memoryMap module
  memoryMap mm (
    .data_a(data_a),
    .data_b(data_b),
    .addr_a(addr_a),
    .addr_b(addr_b),
    .write_a(write_a),
    .write_b(write_b),
    .clk(clk),
    .InputData(InputData),
    .OutputDataA(OutputDataA),
    .OutputDataB(OutputDataB)
  );

  always begin
	  #5 
    clk = ~clk;
  end
    
  initial begin
    data_a = 16'b0;
    data_b = 16'b0;
    addr_a = 16'b0;
    addr_b = 16'b0;
    write_a = 1'b0;
    write_b = 1'b0;
    clk = 1'b0;
    InputData = 8'b0;

    #10;
	  write_a = 1'b1;
	  write_b = 1'b0;
    
    for(i = 0; i < 32; i = i+1) begin
      data_a = i;
      addr_a = i;
      #10;
	  end

  	addr_a = 16'b0;
	  addr_b = 16'b0;
	  write_a = 1'b0;
  	write_b = 1'b1;
  	#10;
    
    for(i = 32; i < 64; i = i+1) begin
      data_a = i;
      addr_a = i;
      #10;
	  end
    
    addr_a = 16'b0;
  	addr_b = 16'b0;
  	write_a = 1'b0;
  	write_b = 1'b0;	
  	#10;
    
    for(i = 510; i < 514; i = i+1) begin
      addr_a = i;
      addr_b = i;
      #10;
    end
	 
   #100;
	  $finish;
    
  end

endmodule 