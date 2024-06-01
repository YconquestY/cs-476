module motionDetect #(
    parameter [7:0] customInstructionId = 8'd1,  // Differ to sobelCi ID
    parameter [7:0] threshold = 8'd10            // Threshold for motion detection
) (
    input wire start,
    input wire [7:0] clampSobelFrame1,  // clampSobel for previous frame
    input wire [7:0] clampSobelFrame2,  // clampSobel for current frame
    input wire [7:0] iseId,
    output wire done,
    output wire [31:0] result
);

    wire s_isMyCustomInstruction = (iseId == customInstructionId) && start;

    // calculate the difference between two frames
    wire [7:0] diffSobel = (clampSobelFrame1 > clampSobelFrame2) ? (clampSobelFrame1 - clampSobelFrame2) : (clampSobelFrame2 - clampSobelFrame1);
    wire [7:0] motionDetected = (diffSobel > threshold) ? 8'hFF : 8'h00;

    assign result = s_isMyCustomInstruction ? {24'b0, motionDetected} : 32'd0;
    assign done = s_isMyCustomInstruction;

endmodule

/*module topModule (
    input wire start,
    input wire [31:0] valueA_frame1,
    input wire [31:0] valueB_frame1,
    input wire [31:0] valueA_frame2,
    input wire [31:0] valueB_frame2,
    input wire [7:0] iseId,
    output wire done,
    output wire [31:0] result
);

    wire done_sobel1, done_sobel2;
    wire [31:0] result_sobel1, result_sobel2;
    wire [7:0] clampSobel_frame1, clampSobel_frame2;

    // 实例化第一个 sobelCi 模块
    sobelCi #(.customInstructionId(8'd0)) sobelCi_inst1 (
        .start(start),
        .valueA(valueA_frame1),
        .valueB(valueB_frame1),
        .iseId(iseId),
        .done(done_sobel1),
        .result(result_sobel1)
    );

    // 实例化第二个 sobelCi 模块
    sobelCi #(.customInstructionId(8'd0)) sobelCi_inst2 (
        .start(start),
        .valueA(valueA_frame2),
        .valueB(valueB_frame2),
        .iseId(iseId),
        .done(done_sobel2),
        .result(result_sobel2)
    );

    assign clampSobel_frame1 = result_sobel1[7:0];
    assign clampSobel_frame2 = result_sobel2[7:0];

    // 实例化 motionDetect 模块
    motionDetect #(.customInstructionId(8'd1)) motionDetect_inst (
        .start(start),
        .clampSobelFrame1(clampSobel_frame1),
        .clampSobelFrame2(clampSobel_frame2),
        .iseId(iseId),
        .done(done),
        .result(result)
    );

endmodule
*/