module ramDmaCi #(parameter [7:0] customId = 8'h00)
                 (input  wire        start,
                                     clock,
                                     reset,
                  input  wire [31:0] valueA, // address
                                     valueB, // data interface
                  input  wire [ 7:0] ciN,
                  output wire        done,
                  output wire [31:0] result,
                  // bus interface
                  output wire        requestOut,
                  input  wire        grantedIn,

                  input  wire [31:0] addressDataIn,
                  output wire [31:0] addressDataOut
                  output wire [ 3:0] byteEnablesOut,
                  output wire [ 7:0] burstSizeOut,
                  output wire        readNotWrite,
                  output wire        beginTransactionOut,
                  input  wire        endTransactionIn,
                  output wire        endTransactionOut,
                  input  wire        dataValidIn,
                  output wire        dataValidOut,
                  input  wire        busyIn,
                  input  wire        busErrorIn);
    reg  [31: 0] mem [511:0]; // 512 32b words, i.e., 2KB

    wire [ 8: 0] addr;
    wire         writeen;
    wire [31:10] valid;

    assign addr    = valueA[8:0];
    assign writeen = valueA[9];
    // CPU-side port
    assign valid   = valueA[31:10] == 0;

    always @ (posedge clock) begin
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
                    result <= mem[addr]; // 2-cycle read latency
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
    wire [ 2:0] map;    // register map
    reg  [31:0] bAddr;  // bus address
    reg  [ 8:0] mAddr;  // SRAM address
    reg  [ 9:0] blockS; // block size
    reg  [ 7:0] burstS; // burst size
    /* read-only register (by CPU) indicating the status of data transfer
     *
     * This is an internal register that changes automatically according to
     * data transfer progress.
     *
     * 00: idle
     * 01: data transfer in progress
     * 10: error
     * 11: error
     */
    reg [1:0] status;  // bit 0: busy? bit 1: error?
    /* write-only register (by CPU) instructing the DMA controller to do data
     * transfer 
     *
     * 00: idle
     * 01: from bus  to SRAM
     * 10: from SRAM to bus
     * 11: undefined
     */
    reg [1:0] control; 
    
    assign map = valueA[12:10];
    
    always @ (negedge clock) begin // Is `reset` in the sensitivity list?
        if (reset) begin
            done   <= 1'b0; // `=`?
            result <= 32'x;
            // duplicate reset?
            for (integer i = 0; i < 512; i = i + 1) begin
                mem[i] <= 32'0;
            end
            map     <=  3'0;
            bAddr   <= 32'0;
            mAddr   <=  9'0;
            blockS  <= 10'0;
            burstS  <=  8'0;
            status  <=  2'0;
            control <=  2'0;
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
                        control <= valueB[1:0]; // see https://edstem.org/eu/courses/1113/discussion/104725?answer=198693
                    end
                    default: begin
                        // do nothing
                    end
                    done   <= 1'b1;
                    result <= 32'0;
                endcase
            end
            else begin // read
                case (map)
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
    // request bus access
    reg requestReg;
    reg beginTransactionReg; // not an output signal
    always @ (negedge clock) begin
        if (control[1] ^ control[0]) begin // TRUE for 01 and 10
            requestReg <= 1'b1;
        end
    end

    always @ (negedge clock) begin
        if ((control[1] ^ control[0]) || requestReg) begin
            if (grantedIn) begin
                status <= 2'b01;
                requestOut <= 1'b0; // access granted, finish request
                requestReg <= 1'b0;
                beginTransactionReg <= 1'b1;
            end
            else begin
                // `status` remains unchanged.
                requestOut <= 1'b1; // keep requesting until access granted
            end
        end
    end
    // flip-flop bus signals
    // `grantedIn` not flip-flopped
    reg [31:2] s_addressDataReg; // "copy" of `addressDataIn`; 30b: word alignment
    reg        s_endTransactionReg;
    reg        s_dataValidReg; // "copy" of `dataValidIn`
    // `busyIn`     not flip-flopped
    // `busErrorIn` not flip-flopped
    always @ (negedge clock) begin
        s_addressDataReg    <= (beginTransactionReg == 1'b1) ? addressDataIn[31:2]
                                                             : s_addressDataReg;
        s_endTransactionReg <= (beginTransactionReg == 1'b1) ? endTransactionIn
                                                             : s_endTransactionIn;
        s_dataValidReg      <= (beginTransactionReg == 1'b1) ? dataValidIn
                                                             : s_dataValidReg;
        beginTransactionReg <= (beginTransactionReg == 1'b1) ? 1'b0 // pulse
                                                             : beginTransactionReg;
    end
    // error handling
    always @ (negedge clock) begin
        // TODO: `endTransactionOut`, `status`, and bus-related FFs````
    end

    // TODO: what if `control` is reset as idle when data transfer is in progress?
    // TODO: reset `status` upon transaction completion or error
endmodule