module motionDetect #(
    parameter [7:0] customInstructionId = 8'd1  // Differ to sobelCi ID
) (
  //  input wire clk,
    input wire rst,
    input wire start,
    input wire [31:0] clampSobelFrame1,  // clampSobel for previous frame
    input wire [31:0] clampSobelFrame2,  // clampSobel for current frame
    input wire [7:0] iseId,
    output reg done,
    output reg [31:0] result,
);

    wire s_isMyCustomInstruction = (iseId == customInstructionId) && start;

    // Calculate the difference between two frames
    wire [31:0] motionDetect = clampSobelFrame1 ^ clampSobelFrame2;

    // Initialize the boundaries
    initial begin
        minX = 10'd50; 
        maxX = 10'd10; 
        minY = 9'd50;  
        maxY = 9'd100;    
    end

    // Variables to track the current pixel position
    reg [9:0] currentX = 0;  
    reg [8:0] currentY = 0;  
    reg doneReg = 0;

    always @* begin
        if (rst) begin
            result <= 32'd0;
            doneReg <= 0;
            minX <= 10'd50;
            maxX <= 10'd100;
            minY <= 9'd50;
            maxY <= 9'd100;
            currentX <= 0;
            currentY <= 0;
        end else if (s_isMyCustomInstruction) begin

            // Update the boundaries based on the motionDetect result
            for (integer i = 0; i < 32; i = i + 1) begin
                if (motionDetect[i]) begin
                    if (currentX + i < minX) minX <= currentX + i;
                    if (currentX + i > maxX) maxX <= currentX + i;
                    if (currentY < minY) minY <= currentY;
                    if (currentY > maxY) maxY <= currentY;
                end
            end

            // Update the current pixel position
            if (currentX < 638 - 32) begin //606  608
                currentX <= currentX + 32;
            end else begin
                currentX <= 32- (638 - currentX);
                currentY <= currentY + 1;
            end

            // Check if we have processed all pixels
            if (currentY == 478) begin
                doneReg <= 1;
            end else begin
                doneReg <= 0;
            end
        end else begin
            result <= 32'd0;
            doneReg <= 0;
        end
    end
    assign result = {maxX[8:0], minX[8:0], maxY[6:0], minY[6:0]}; 
    // Output max and min X and Y coordinates as the final out
    assign result = s_isMyCustomInstruction ? {24'b0, clampSobel}{maxX[8:0], minX[8:0], maxY[6:0], minY[6:0]} : 32'd0;
    assign done = s_isMyCustomInstruction ? doneReg : 0;
endmodule