module ramDmaCi #(parameter [7:0] customId = 8'h00)
                 (input  wire        start,
                                     clock,
                                     reset,
                  input  wire [31:0] valueA, // address
                                     valueB, // data interface
                  input  wire [ 7:0] ciN,
                  output wire        done,
                  output wire [31:0] result);
    reg  [31: 0] mem [511:0]; // 512 32b words, i.e., 2KB

    wire [ 8: 0] addr;
    wire         writeen;
    wire [31:10] valid;

    assign addr    = valueA[8:0];
    assign writeen = valueA[9];
    // CPU-side port
    assign valid   = valueA[31:10] == 0;

    always @ (posedge clock or posedge reset) begin
        if (reset) begin
            done   <= 1'b0; // `=`?
            result <= 32'x;
            for (integer i = 0; i < 512; i = i + 1) begin
                mem[i] <= 32'0;
            end
        end
        else begin
            if (start && valid && (ciN == customId)) begin
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
    // DMA-side port
    wire [ 2:0] map;     // (essentially 3b) register map
    reg  [31:0] bAddr;   // bus address
    reg  [ 8:0] mAddr;   // SRAM address
    reg  [ 9:0] blockS;  // block size
    reg  [ 7:0] burstS;  // burst size
    reg  [ 1:0] status;  // bit 0: busy? bit 1: error?
    reg         control; // DMA control: 1 means from bus to SRAM

    assign map = valueA[12:10];
    
    always @ (negedge clock) begin // Is `reset` in the sensitivity list?
        if (reset) begin // Can DMA controller reset SRAM?
            done   <= 1'b0; // `=`?
            result <= 32'x;
            for (integer i = 0; i < 512; i = i + 1) begin
                mem[i] <= 32'0;
            end
        end
        else begin
            if (writeen) begin // write
                case (map)
                    3'b000: begin // write to SRAM
                        mem[addr] <= valueB;
                    end
                    3'b001: begin // write bus start address
                        bAddr <= valueB;
                    end
                    3'b010: begin // write SRAM start address
                        mAddr <= valueB[8:0];
                    end
                    3'b011: begin // write block size
                        blockS <= valueB[9:0];
                    end
                    3'b100: begin // write burst size
                        burstS <= valueB[7:0];
                    end
                    3'b101: begin // write control register
                        control <= 1 // Why 1?
                    end
                    default: begin
                        // do nothing
                    end
                    done   <= 1'b1;
                    result <= 32'0;
                endcase
            end
            else begin // read
                case (control)
                    3'b000: begin // read from SRAM
                        result <= mem[addr];
                    end
                    3'b001: begin // read bus start address
                        result <= bAddr;
                    end
                    3'b010: begin // read SRAM start address
                        result <= {23'0, mAddr};
                    end
                    3'b011: begin // read block size
                        result <= {22'0, blockS};
                    end
                    3'b100: begin // read burst size
                        result <= {24'0, burstS};
                    end
                    3'b101: begin // read status register
                        result <= {30'0, status};
                    end
                    default: begin
                        // do nothing
                    end
                    done <= 1'b1;
                endcase
            end
        end
    end
endmodule