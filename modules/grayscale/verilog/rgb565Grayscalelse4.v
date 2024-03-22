module rgb565Grayscalelse4 #(parameter [7:0] customInstructionId = 8'd0) (
    input  wire        start,
    input  wire [31:0] valueA,
    input  wire [31:0] valueB,
    input  wire [7 :0] iseld,
    output wire        done,
    output wire [31:0] result
);
    wire [7:0] pA0, pA1,
               pB0, pB1;
    rgb565GrayscaleBase p0 (.value(valueA[31:16]),
                            .result(pA0));
    rgb565GrayscaleBase p1 (.value(valueA[15: 0]),
                            .result(pA1));
    rgb565GrayscaleBase p2 (.value(valueB[31:16]),
                            .result(pB0));
    rgb565GrayscaleBase p3 (.value(valueB[15: 0]),
                            .result(pB1));
    assign result = (start && (iseld == customInstructionId)) ? {pA0, pA1, pB0, pB1} : 0;
    assign done   = (start && (iseld == customInstructionId)) ? 1 : 0;
endmodule