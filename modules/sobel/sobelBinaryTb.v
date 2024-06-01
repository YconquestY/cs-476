`include "sobel.v"
`timescale 1ps/1ps

module sobelTb;
    // Parameters
    parameter [7:0] computeId = 8'd1;
    parameter [7:0] computeReturnId = 8'd2;
    parameter [7:0] threshold = 8'd24;

    // Inputs
    reg start;
    reg clock;
    reg reset;
    reg [31:0] valueA;
    reg [31:0] valueB;
    reg [7:0] iseId;

    // Outputs
    wire done;
    wire [31:0] result;

    initial begin
        reset = 1'b1;
        clock = 1'b1;
        repeat(4) begin
            #5 clock = ~clock;
        end
        reset = 1'b0;
        forever begin
            #5 clock = ~clock;
        end
    end
    
    // Instantiate the Unit Under Test (UUT)
    sobelCi #(
        .computeId(computeId),
        .computeReturnId(computeReturnId),
        .threshold(threshold)
    ) uut (
        .start(start),
        .clock(clock),
        .reset(reset),
        .valueA(valueA),
        .valueB(valueB),
        .iseId(iseId),
        .done(done),
        .result(result)
    );

    integer i;
    initial begin
        // Initialize Inputs
        start = 1'b0;
        valueA = 32'd0;
        valueB = 32'd0;
        iseId = 8'd0;

        // Wait for global reset to finish
        #20;

        for (i = 0; i < 31; i = i + 1) begin
            iseId = computeId;
            start = 1'b1;
            valueA = {8'd5, 8'd6, 8'd7, 8'd8};
            valueB = {8'd1, 8'd2, 8'd3, 8'd4};
            #10;
        end

        iseId = computeReturnId;
        start = 1'b1;
        valueA = {8'd1, 8'd2, 8'd3, 8'd4};
        valueB = {8'd5, 8'd6, 8'd7, 8'd8};
        #10;

        iseId = 1'b0;
        start = 1'b0;
        valueA = 32'd0;
        valueB = 32'd0;
        #20;

        // Finish simulation
        $finish;
    end

    initial begin
        $dumpfile("sobel.vcd");
        $dumpvars(1, uut);
    end
endmodule
