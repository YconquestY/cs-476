module rgb565GrayscaleBase #(parameter [7:0] customInstructionId = 8'd0) (
    input  wire [15:0] value,
    output wire [ 7:0] result
);
    wire [ 7:0] r, g, b;
    wire [16:0] gray;

    assign r = {value[15:11], 3'd0};
    assign g = {value[10: 5], 2'd0};
    assign b = {value[ 4: 0], 3'd0};

    assign gray   = (8'd54 * r + 8'd183 * g + 8'd19 * b) >> 8;
    assign result = gray[7:0];
endmodule