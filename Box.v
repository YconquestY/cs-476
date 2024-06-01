module motionDetect #(
    parameter [7:0] computeId = 8'd1,
    parameter [7:0] computeReturnId = 8'd1 // Differ to sobelCi ID
) (
  //  input wire clk,
    input wire clock,
    input wire rst,
    input wire start,
    input wire [31:0] clampSobelFrame1,  // clampSobel for previous frame 
    input wire [31:0] clampSobelFrame2,  // clampSobel for current frame
    input wire [7:0] iseId,
    output wire done,
    output wire [31:0] result
);

    wire isComputeInstr = iseId == computeId;
    wire isComputeReturnInstr = iseId == computeReturnId;

    // Calculate the difference between two frames
    wire [31:0] motionDetect = clampSobelFrame1 ^ clampSobelFrame2;

    wire [7:0] motion1 = motionDetect[7:0];
    wire [7:0] motion2 = motionDetect[15:8];
    wire [7:0] motion3 = motionDetect[23:16];
    wire [7:0] motion4 = motionDetect[31:24];

    // Initialize the boundaries
    
    reg [9:0] minX = 10'd640; 
    reg [9:0] maxX = 10'd1; 
    reg [8:0] minY = 9'd478;  
    reg [8:0] maxY = 9'd1;  
    reg [9:0] currentX = 0;  
    reg [8:0] currentY = 0;

    reg doneReg = 0;  
    always @(posedge clock) begin
        if (rst) begin
            minX <= 10'd640;
            maxX <= 10'd1;
            minY <= 9'd478;
            maxY <= 9'd1;
            currentX <= 0;
            currentY <= 1;
            doneReg <= 0;

        end else if (isComputeInstr) begin
            if (motion4 > 0) begin // left 8 pixels
                if (currentX < minX) 
                    minX <= currentX + 1; // incase of 0
                if (currentX + 8 > maxX) 
                    maxX <= currentX + 8;
            end else if (motion3 > 0) begin // left 8-16 pixels
                if (currentX +8 < minX) 
                    minX <= currentX +8;
                if (currentX + 16 > maxX) 
                    maxX <= currentX + 16;
            end else if (motion2 > 0) begin // left 16-24 pixels
                if (currentX + 16 < minX) 
                    minX <= currentX +16;
                if (currentX + 24 > maxX) 
                    maxX <= currentX + 24;
            end else if (motion1 > 0) begin // left 24-32 pixels
                if (currentX + 24 < minX) 
                    minX <= currentX + 24;
                if (currentX + 32 > maxX) 
                    maxX <= currentX + 32;
            end
             
            if (motionDetect > 0) begin
                if (currentY < minY) 
                    minY <= currentY;

                if (currentY > maxY) 
                    maxY <= currentY;
            end

            if (currentX < 608) begin 
                currentX <= currentX + 32;
            end else begin
                currentX <= 0;
                currentY <= currentY + 1;
            end

            // Check if we have processed all pixels
            if (currentY == 478) begin
                doneReg <= 1;
            end else begin
                doneReg <= 0;
            end

        end else begin
            doneReg <= 0;
            minX <= 10'd638;
            maxX <= 10'd0;
            minY <= 9'd478;
            maxY <= 9'd0;
        end
    end
    
    // Output max and min X and Y coordinates as the final output
    wire [31:0] resultReg = { maxY[8:2], minY[8:2], maxX[9:1], minX[9:1]}; 
    assign done = (isComputeInstr || isComputeReturnInstr) && start && doneReg;
  //  assign result = isComputeReturnInstr ? resultReg : 32'd0;
    assign result = resultReg ;
endmodule

