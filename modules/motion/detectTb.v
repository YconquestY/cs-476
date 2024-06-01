`include "motionDetect.v"
`timescale 1ps/1ps

module tb_motionDetect;
    // Parameters
    parameter [7:0] customInstructionId = 8'd1;
    parameter [7:0] threshold = 8'd10;

    // Inputs
    reg start;
    reg [7:0] clampSobelFrame1;
    reg [7:0] clampSobelFrame2;
    reg [7:0] iseId;

    // Outputs
    wire done;
    wire [31:0] result;

    // Instantiate the Unit Under Test (UUT)
    motionDetect #(
        .customInstructionId(customInstructionId),
        .threshold(threshold)
    ) uut (
        .start(start),
        .clampSobelFrame1(clampSobelFrame1),
        .clampSobelFrame2(clampSobelFrame2),
        .iseId(iseId),
        .done(done),
        .result(result)
    );

    initial begin
        // Initialize Inputs
        start = 0;
        clampSobelFrame1 = 0;
        clampSobelFrame2 = 0;
        iseId = 0;

        // Wait for global reset to finish
        #20;

        // Test Case 1: No motion detected
        iseId = customInstructionId;
        start = 1;
        clampSobelFrame1 = 8'd50;
        clampSobelFrame2 = 8'd55; // Difference = 5, less than threshold
        #20;

        // Test Case 2: Motion detected
        start = 1;
        clampSobelFrame1 = 8'd50;
        clampSobelFrame2 = 8'd70; // Difference = 20, greater than threshold
        #20;

        // Test Case 3: Custom instruction ID does not match
        iseId = customInstructionId + 1;
        start = 1;
        clampSobelFrame1 = 8'd50;
        clampSobelFrame2 = 8'd70; // Difference = 20, but ID does not match
        #20;

        // Finish simulation
        $finish;
    end

    initial begin
        $dumpfile("motionDetect.vcd");
        $dumpvars(0, tb_motionDetect);
    end
endmodule
