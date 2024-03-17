`timescale 1ns/1ns
`include "greyscale.v"
module testbench;
  reg clock;
  reg reset;
  reg start;
  reg stall;
  reg busIdle;
  reg [31:0] valueA;
  reg [31:0] valueB;
  reg [7:0] ciN;
  wire done;
  wire [31:0] result;

  // Instantiate the module under test
  profileCi #(8'h00) dut (.start(start), .clock(clock), .reset(reset), .stall(stall), .busIdle(busIdle), .valueA(valueA), .valueB(valueB), .ciN(ciN), .done(done), .result(result));

  // Clock generation
  always begin
    clock = 0;
    #5;
    clock = 1;
    #5;
  end

  // Test stimulus
  initial begin
    reset = 1;
    start = 0;
    stall = 0;
    busIdle = 1;
    valueA = 32'h00000000;
    valueB = 32'h00000000;
    ciN = 8'h00;

    #10;
    reset = 0;
    start = 1;
    stall = 0;
    busIdle = 0;
    valueA = 32'h00000001;
    valueB = 32'h00000001;
    ciN = 8'h00;

    #20;
    reset = 0;
    start = 0;
    stall = 1;
    busIdle = 0;
    valueA = 32'h00000002;
    valueB = 32'h00000002;
    ciN = 8'h00;

    #30;
    reset = 0;
    start = 1;
    stall = 0;
    busIdle = 0;
    valueA = 32'h00000003;
    valueB = 32'h00000003;
    ciN = 8'h00;

    #40;
    reset = 0;
    start = 0;
    stall = 0;
    busIdle = 1;
    valueA = 32'h00000000;
    valueB = 32'h00000000;
    ciN = 8'h00;

    #50;
    $finish;
  end

   initial
    begin
      $dumpfile("grayscale.vcd");
      $dumpvars(1,dut);
    end
endmodule
