module sobelCi #(
    parameter [7:0] computeId = 8'd0,
    parameter [7:0] computeReturnId = 8'd0,
    parameter [7:0] threshold = 8'd127 // threshold for binarization
) (
    input  wire        start,
                       clock,
                       reset,
    input  wire [31:0] valueA,
    input  wire [31:0] valueB,
    input  wire [ 7:0] iseId,
    output wire        done,
    output wire [31:0] result
);
    wire isComputeInstr = iseId == computeId;
    wire isComputeReturnInstr = iseId == computeReturnId;
    /* ----------------------------------------------
     * |    top left |    top middle |    top right |
     * ----------------------------------------------
     * | middle left |               | middle right |
     * ----------------------------------------------
     * | bottom left | bottom middle | bottom right |
     * ----------------------------------------------
     */    
    wire [7:0] topLeft   = valueA[31:24];
    wire [7:0] topMiddle = valueA[23:16];
    wire [7:0] topRight  = valueA[15: 8];

    wire [7:0] middleLeft  = valueA[7:0];
    wire [7:0] middleRight = valueB[7:0];

    wire [7:0] bottomLeft   = valueB[31:24];
    wire [7:0] bottomMiddle = valueB[23:16];
    wire [7:0] bottomRight  = valueB[15: 8];
    /* Sobel kernels
     * dX             dY
     * -------------- ----------------
     * | -1 | 0 | 1 | |  1 |  2 |  1 |
     * -------------- ----------------
     * | -2 | 0 | 2 | |  0 |  0 |  0 |
     * -------------- ----------------
     * | -1 | 0 | 1 | | -1 | -2 | -1 |
     * -------------- ----------------
     */
    // TODO: signed substraction
    wire signed [ 8:0] topX    = topRight    - topLeft,
                       middleX = middleRight - middleLeft,
                       bottomX = bottomRight - bottomLeft;
    wire signed [ 9:0] tmpX = topX + bottomX,
                       middleX2 = {middleX, 1'b0};
    wire signed [10:0] sobelX = tmpX + middleX2;

    wire signed [ 8:0] leftY   = topLeft   - bottomLeft,
                       middleY = topMiddle - bottomMiddle,
                       rightY  = topRight  - bottomRight;
    wire signed [ 9:0] tmpY = leftY + rightY,
                       middleY2 = {middleY, 1'b0};
    wire signed [10:0] sobelY = tmpY + middleY2;

    wire [ 9:0] absSobelX = (sobelX[10] == 1'b0) ? sobelX : -sobelX;
    wire [ 9:0] absSobelY = (sobelY[10] == 1'b0) ? sobelY : -sobelY;
    wire [10:0] sumSobel = absSobelX + absSobelY;
    wire        binarySobel = (sumSobel > threshold) ? 1'b1 : 1'b0;
     
    reg [ 4:0] count;
    reg [30:0] resultReg; // first 31 pixels
    
    always @ (posedge clock) begin
        if (reset) begin
            resultReg <= 31'd0;
            count <= 5'd31;
        end
        else if (start) begin
            resultReg <= resultReg | (binarySobel << count);
            count <= count + 1; // start from 0
        end
    end

    assign done = (isComputeInstr || isComputeReturnInstr) && start;
    assign result = count == 5'd31 ? {binarySobel, resultReg}
                                   : 32'd0;
endmodule
