`include "Sobel.v"
`timescale 1ps/1ps

module tb_sobelCi;
    // Parameters
    parameter [7:0] customInstructionId = 8'd0;

    // Inputs
    reg start;
    reg [31:0] valueA;
    reg [31:0] valueB;
    reg [7:0] iseId;

    // Outputs
    wire done;
    wire [31:0] result;

    // Instantiate the Unit Under Test (UUT)
    sobelCi #(
        .customInstructionId(customInstructionId)
    ) uut (
        .start(start),
        .valueA(valueA),
        .valueB(valueB),
        .iseId(iseId),
        .done(done),
        .result(result)
    );

    initial begin
        // Initialize Inputs
        start = 0;
        valueA = 0;
        valueB = 0;
        iseId = 0;

        // Wait for global reset to finish
        #20;

        // Test Case 1: Custom instruction ID matches
        iseId = customInstructionId;
        start = 1;
        valueA = {8'd255, 8'd100, 8'd50, 8'd0}; // graypixel3, graypixel2, graypixel1, graypixel0
        valueB = {8'd255, 8'd200, 8'd150, 8'd100}; // graypixel8, graypixel7, graypixel6, graypixel5
        #20;

        valueA = {8'd255, 8'd255, 8'd255, 8'd255}; // graypixel3, graypixel2, graypixel1, graypixel0
        valueB = {8'd255, 8'd255, 8'd255, 8'd255}; // graypixel8, graypixel7, graypixel6, graypixel5
        #20;

        // Test Case 2: Custom instruction ID does not match
        iseId = customInstructionId + 1;
        start = 1;
        valueA = {8'd255, 8'd100, 8'd50, 8'd0}; // graypixel3, graypixel2, graypixel1, graypixel0
        valueB = {8'd255, 8'd200, 8'd150, 8'd100}; // graypixel8, graypixel7, graypixel6, graypixel5
        #20;


        // Finish simulation
        $finish;
    end

    initial begin
        $dumpfile("Sobel.vcd");
        $dumpvars(0, tb_sobelCi);
    end
endmodule
