module Counter #(parameter WIDTH = 32)
                (input wire clock, 
                 input wire reset, 
                 input wire enable,
                 input wire disabled,
                 input wire counterReset,
                 output reg [WIDTH-1:0] count);

    always @(posedge clock or posedge reset) begin
        if (reset)
            count <= 0;
        else if (counterReset)
            count <= 0;
        else if (enable && ~disabled)
            count <= count + 1;
    end
endmodule

module profileCi #(parameter [7:0] customId = 8'h00)
                  (input wire start,
                   input wire clock,
                   input wire reset,
                   input wire stall,
                   input wire busIdle,
                   input wire [31:0] valueA,
                   input wire [31:0] valueB,
                   input wire [7:0] ciN,
                   output reg done,
                   output reg [31:0] result);

    wire [31:0] counter0, counter1, counter2, counter3;

    // Instantiate counters
    Counter #(32) counter_inst0 (.clock(clock), .reset(reset), .enable(valueB[0]), .disabled(valueB[4]), .counterReset(valueB[8]), .count(counter0));
    Counter #(32) counter_inst1 (.clock(clock), .reset(reset), .enable(valueB[1]), .disabled(valueB[5]), .counterReset(valueB[9]), .count(counter1));
    Counter #(32) counter_inst2 (.clock(clock), .reset(reset), .enable(valueB[2]), .disabled(valueB[6]), .counterReset(valueB[10]), .count(counter2));
    Counter #(32) counter_inst3 (.clock(clock), .reset(reset), .enable(valueB[3]), .disabled(valueB[7]), .counterReset(valueB[11]), .count(counter3));

    // Output logic
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            done <= 0;
            result <= 0;
        end else if (start && (ciN == customId)) begin
            done <= 1;
            case (valueA[1:0])
                2'b00: result <= counter0;
                2'b01: result <= counter1;
                2'b10: result <= counter2;
                2'b11: result <= counter3;
                default: result <= 0;
            endcase
        end else begin
            done <= 0;
            result <= 0;
        end
    end

endmodule
