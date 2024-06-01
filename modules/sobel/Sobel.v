module sobelCi #(
    parameter [7:0] customInstructionId = 8'd0
) (
    input wire start,
    input wire [31:0] valueA,
    input wire [31:0] valueB,
    input wire [7:0] iseId,
    output wire done,
    output wire [31:0] result
);
    wire s_isMyCustomInstruction = (iseId == customInstructionId) && start;

    // grayscale values for 8 pixels around the center pixel
    wire [7:0] graypixel3 = valueA[31:24];
    wire [7:0] graypixel2 = valueA[23:16];
    wire [7:0] graypixel1 = valueA[15:8];
    wire [7:0] graypixel0 = valueA[7:0];

    wire [7:0] graypixel8 = valueB[31:24];
    wire [7:0] graypixel7 = valueB[23:16];
    wire [7:0] graypixel6 = valueB[15:8];
    wire [7:0] graypixel5 = valueB[7:0];

    //times 2
    wire [8:0] graypixel5_d = {graypixel5, 1'b0};
    wire [8:0] graypixel3_d = {graypixel3, 1'b0};
    wire [8:0] graypixel7_d = {graypixel7, 1'b0};
    wire [8:0] graypixel1_d = {graypixel1, 1'b0};

    // Sobel kernel for X and Y
    wire signed [10:0] sobelX = graypixel2 + graypixel5_d + graypixel8 - graypixel0 - graypixel3_d - graypixel6;
    wire signed [10:0] sobelY = graypixel6 + graypixel7_d + graypixel8 - graypixel0 - graypixel1_d - graypixel2;

    // 8 byte result to print on screen
    wire [10:0] absSobelX = (sobelX > 0) ? sobelX : -sobelX;
    wire [10:0] absSobelY = (sobelY > 0) ? sobelY : -sobelY;
    wire [10:0] sumSobel = absSobelX + absSobelY;
    wire [7:0] clampSobel = (sumSobel > 255) ? 8'hFF : sumSobel;

    assign result = s_isMyCustomInstruction ? {24'b0, clampSobel} : 32'd0;
    assign done = s_isMyCustomInstruction;

endmodule
/*grayscale[pixelIndex - width - 1]=graypixel0    grayscale[pixelIndex - width]=graypixel1   grayscale[pixelIndex - width + 1]=graypixel2
  grayscale[pixelIndex - 1]        =graypixel3    grayscale[pixelIndex]                      grayscale[pixelIndex + 1]        =graypixel5
  grayscale[pixelIndex + width - 1]=graypixel6    grayscale[pixelIndex + width]=graypixel7   grayscale[pixelIndex + width + 1]=graypixel8


uint32_t getValueA(uint8_t *grayscale, int pixelIndex, int width) {
    uint32_t valueA;
    uint8_t *valueA_ptr = (uint8_t *)&valueA;

    valueA_ptr[0] = grayscale[pixelIndex - width - 1];
    valueA_ptr[1] = grayscale[pixelIndex - width];
    valueA_ptr[2] = grayscale[pixelIndex - width + 1];
    valueA_ptr[3] = grayscale[pixelIndex - 1];

    return valueA;
}

uint32_t getValueB(uint8_t *grayscale, int pixelIndex, int width) {
    uint32_t valueB;
    uint8_t *valueB_ptr = (uint8_t *)&valueB;

    valueB_ptr[0] = grayscale[pixelIndex + 1];
    valueB_ptr[1] = grayscale[pixelIndex + width - 1];
    valueB_ptr[2] = grayscale[pixelIndex + width];
    valueB_ptr[3] = grayscale[pixelIndex + width + 1];

    return valueB;
}

*/