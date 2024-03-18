module Counter #(parameter WIDTH = 32)
                (input wire clock, 
                 input wire reset, 
                 input wire enable,
                 input wire disabled,
                 output reg [WIDTH-1:0] count);

    always @(posedge clock) begin
        if (reset || disabled) begin
            count <= 0;
        end
        else if (enable && ~disabled) begin
            count <= count + 1;
        end
        else begin
            count <= count;
        end
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
    reg  [31:0] control;

    // Instantiate counters
    Counter #(32) counter_inst0 (.clock(clock), .reset(control[8]  || reset), .enable(control[0])           , .disabled(control[4]), .count(counter0));
    Counter #(32) counter_inst1 (.clock(clock), .reset(control[9]  || reset), .enable(control[1] && stall)  , .disabled(control[5]), .count(counter1));
    Counter #(32) counter_inst2 (.clock(clock), .reset(control[10] || reset), .enable(control[2] && busIdle), .disabled(control[6]), .count(counter2));
    Counter #(32) counter_inst3 (.clock(clock), .reset(control[11] || reset), .enable(control[3])           , .disabled(control[7]), .count(counter3));

    // Output logic
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            done <= 0;
            result <= 0;
        end else if (start && (ciN == customId)) begin
            control <= valueB;
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
