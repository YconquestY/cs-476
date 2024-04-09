module ramDmaCi #(parameter [7:0] customId = 8'h00)
                 (input  wire        start,
                                     clock,
                                     reset,
                  input  wire [31:0] valueA, // address
                                     valueB, // data interface
                  input  wire [ 7:0] ciN,
                  output wire        done,
                  output wire [31:0] result);
    reg  [31: 0] mem [511:0];

    wire [ 8: 0] addr;
    wire         writeen;
    wire [31:10] valid;

    assign addr    = valueA[8:0];
    assign writeen = valueA[9];
    assign valid   = valueA[31:10];
    // CPU-side port
    always @ (posedge clock or posedge reset) begin
        if (reset) begin
            done   <= 1'b0; // `=`?
            result <= 32'x;
            for (integer i = 0; i < 512; i = i + 1) begin
                mem[i] <= 32'0;
            end
        end
        else begin
            if (start && (valid == 0) && (ciN == customId)) begin
                if (writeen) begin // write
                    mem[addr] <= valueB;
                    result <= 32'0;
                end
                else begin // read
                    result <= mem[addr];
                end
                done <= 1'b1;
            end
            else begin
                done   <= 1'b0;
                result <= 32'x;
            end
        end
    end

    wire [3:0] control;
    wire 

    assign control = valueA[12:9];
    // DMA-side port
    always @ (negedge clock) begin
        if (reset) begin // Can DMA controller reset SRAM?
            done   <= 1'b0; // `=`?
            result <= 32'x;
            for (integer i = 0; i < 512; i = i + 1) begin
                mem[i] <= 32'0;
            end
        end
        else begin
        case (control)
            4'b0000: begin // read
                result <= mem[addr];
            end
            4'b0001: begin // write
                mem[addr] <= valueB;
                result <= 32'0;
            end
            4'b0010: begin // read bus start address
                // TODO
            end
            4'b0011: begin // write bus start address
                // TODO
            end
            4'b0100: begin // read and write
                result <= mem[addr];
                mem[addr] <= valueB;
            end
            3'b101: begin // read and write
                result <= mem[addr];
                mem[addr] <= valueB;
            end
            3'b110: begin // read and write
                result <= mem[addr];
                mem[addr] <= valueB;
            end
            default: begin // read and write
                result <= mem[addr];
                mem[addr] <= valueB;
            end
        endcase
        end
    end
endmodule