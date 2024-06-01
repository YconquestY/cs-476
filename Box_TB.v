`include "Box.v"
`timescale 1ps/1ps
module tb_Box;

  // Parameters
  parameter CLOCK_PERIOD = 10; // Clock period in time units

  // Inputs to the DUT
  reg clock;
  reg rst;
  reg start;
  reg [31:0] clampSobelFrame1;
  reg [31:0] clampSobelFrame2;
  reg [7:0] iseId;

  // Outputs from the DUT
  wire done;
  wire [31:0] result;

  // Instantiate the Device Under Test (DUT)
  motionDetect #(
    .computeId(8'd1),
    .computeReturnId(8'd1)
  ) dut (
    .clock(clock),
    .rst(rst),
    .start(start),
    .clampSobelFrame1(clampSobelFrame1),
    .clampSobelFrame2(clampSobelFrame2),
    .iseId(iseId),
    .done(done),
    .result(result)
  );

  // Clock generation
  initial begin
    clock = 1;
    forever #(5) clock = ~clock;
  end


  initial begin
    // Initialize inputs
    rst = 1;
    start = 0;
    clampSobelFrame1 = 32'd0;
    clampSobelFrame2 = 32'd0;
    iseId = 8'd1;
    #10;


    rst = 0;
    iseId = 8'd1;
    start = 1;
    // Repeat 21 times
    for (integer i = 0; i < 24; i = i + 1) begin
      clampSobelFrame1 = 32'h0FFFFFFF; 
      clampSobelFrame2 = 32'hFFFFFFFF; 
      #10;
    end
    
    iseId = 8'd0;
    // Wait for a few clock cycles to ensure processing is complete
    # 20;
    // Finish simulation
    $finish;
  end
initial begin
        $dumpfile("Box.vcd");
        $dumpvars(0, tb_Box);
    end
endmodule
