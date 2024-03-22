module rgb565Grayscalelse #(parameter [7:0] customInstructionId = 8'd0) (
    input  wire        start,
    input  wire [31:0] valueA,
    input  wire [ 7:0] iseld,
    output wire        done,
    output wire [31:0] result
);
    wire [ 7:0] r, g, b;
    wire [16:0] gray;

    assign r = {valueA[15:11], 3'd0};
    assign g = {valueA[10: 5], 2'd0};
    assign b = {valueA[ 4: 0], 3'd0};

    assign gray   = (8'd54 * r + 8'd183 * g + 8'd19 * b) >> 8;
    assign result = (start && (iseld == customInstructionId)) ? {24'd0, gray[7:0]} : 0;
    assign done   = (start && (iseld == customInstructionId)) ? 1 : 0;
endmodule
