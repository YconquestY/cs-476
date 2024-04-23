module ramDmaCi #(parameter [7:0] customId = 8'h00)
                 (input  wire        start,
                                     clock,
                                     reset,
                  input  wire [31:0] valueA, // address
                                     valueB, // data interface
                  input  wire [ 7:0] ciN,
                  output wire        done,
                  output reg  [31:0] result,
                  // bus interface
                  input  wire        grantedIn,
                  input  wire [31:0] addressDataIn,
                  input  wire        endTransactionIn,
                                     dataValidIn,
                                     busErrorIn,
                                     busyIn,
                  
                  output reg        requestOut,
                  output reg [31:0] addressDataOut,
                  output reg [ 3:0] byteEnablesOut,
                  output reg [ 7:0] burstSizeOut,
                  output reg        readNotWriteOut,
                                    beginTransactionOut,
                                    endTransactionOut,
                                    dataValidOut);
    reg  [31: 0] mem [511:0]; // 512 32b words, i.e., 2KB

    wire [ 8: 0] addr;
    wire         writeen;
    wire [31:10] valid;
    reg          rdDone;

    assign addr    = valueA[8:0];
    assign writeen = valueA[9];
    // CPU-side port
    wire port1WrDone;

    assign valid = valueA[31:10] == 0;
    assign port1WrDone = !reset && start && valid && (ciN == customId) && writeen;

    always @ (posedge clock) begin
        if (reset) begin
            rdDone <= 1'b0;
            result <= 32'd0;
            for (integer i = 0; i < 512; i = i + 1) begin
                mem[i] <= 32'd0;
            end
        end
        else if (start && valid && (ciN == customId)) begin
            if (writeen) begin // write
                mem[addr] <= valueB;

                rdDone <= 1'b0;
                result <= 32'd0;
            end
            else begin // read
                result <= mem[addr]; // 2-cycle read latency
                rdDone <= 1'b1;
            end
        end
        else begin
            rdDone <= 1'b0;
            result <= 32'd0;
        end
    end
    // DMA-side port
    wire        port2WrDone;
    wire [ 2:0] map;    // register map
    reg  [31:0] bAddr;  // bus address; increment by 4
    reg  [ 8:0] mAddr;  // SRAM address; increment by 1
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
    assign port2WrDone = !reset && start && (ciN == customId) && writeen;
    
    always @ (negedge clock) begin // Is `reset` in the sensitivity list?
        if (reset) begin
            rdDone <= 1'b0;
            result <= 32'd0;
            // duplicate reset?
            for (integer i = 0; i < 512; i = i + 1) begin
                mem[i] <= 32'd0;
            end
            bAddr   <= 32'd0;
            mAddr   <=  9'd0;
            blockS  <= 10'd0;
            burstS  <=  8'd0;
            status  <=  2'd0;
            control <=  2'd0;
        end
        else if (start && (ciN == customId)) begin
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
                endcase
                rdDone <= 1'b0;
                result <= 32'd0;
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
                        result <= {23'd0, mAddr};
                    end
                    3'b011: begin // read block size
                        result <= {22'd0, blockS};
                    end
                    3'b100: begin // read burst size
                        result <= {24'd0, burstS};
                    end
                    3'b101: begin // read status register
                        result <= {30'd0, status};
                    end
                    default: begin
                        // do nothing
                    end
                endcase
                rdDone <= 1'b1;
            end
        end
        else begin
            rdDone <= 1'b0;
            result <= 32'd0;
        end
    end

    assign done = rdDone || port1WrDone || port2WrDone;
    
    localparam idle       = 3'd0,
               request    = 3'd1,
               granted    = 3'd2,
               read       = 3'd3,
               rdComplete = 3'd4,
               write      = 3'd5,
               wrComplete = 3'd6,
               error      = 3'd7;
    reg [2:0] current, // state
              next;
    reg [7:0] txProgress;      // single transaction progress (descending)
    reg [9:0] dataProgress;    // aggregate transfer progress (ascending)
    reg       readNotWriteReg; // data transfer direction

    // state transition
    always @ (negedge clock) begin
        if (reset) begin
            current <= idle;

            txProgress   <=  8'd0;
            dataProgress <= 10'd0;
        end
        else begin
            current <= next;
        end
    end
    // helper function to computing number of words to be transferred
    function [9:0] remaining;
    input [9:0] blockS,
                dataProgress;
    begin
        remaining = blockS - dataProgress;
    end
    endfunction
    // next state logic
    always @ (*) begin
        next = current; // default case
        case (current)
            idle: begin
                if (blockS > 0 && (control[1] ^ control[0])) begin // `burstS` is always positive.
                    next = request;
                    readNotWriteReg = control == 2'b01; // only set, never reset
                end
                /*
                else
                    next = idle;
                */
                dataProgress = 0;
            end
            request: begin
                if (busErrorIn)
                    next = error;
                else if (grantedIn)
                    next = granted;
                /*
                else
                    next = request;
                */
            end
            granted: begin
                if (busErrorIn)
                    next = error;
                else begin
                    if (readNotWriteReg) // read from bus
                        next = read;
                    else // write to bus
                        next = write;

                    if (remaining(blockS, dataProgress) > burstS + 1)
                        txProgress = burstS;
                    else
                        txProgress = remaining(blockS, dataProgress);
                    // `dataProgress` reset in `idle` state
                end
            end
            read: begin
                if (busErrorIn)
                    next = error;
                else begin
                    /*
                    if (txProgress > 0)
                        next = read;
                    else*/ if (txProgress == 0) begin
                        if (endTransactionIn && !busyIn)
                            next = rdComplete;
                        /*
                        else if (dataValidIn && !busyIn)
                            next = read;
                        */
                        else
                            next = read;
                    end

                    if (dataValidIn && !busyIn) begin
                        mem[mAddr] = addressDataIn;

                        bAddr = bAddr + 4;
                        mAddr = mAddr + 1;

                        if (txProgress > 0)
                            txProgress = txProgress - 1;
                        dataProgress = dataProgress + 1;
                    end
                end
            end
            rdComplete: begin
                if (dataProgress == blockS)
                    next = idle;
                else
                    next = request;
            end
            write: begin
                if (busErrorIn)
                    next = error;
                else begin
                    /*
                    if (txProgress > 0)
                        next = write;
                    else*/ if (txProgress == 0)begin
                        if (!busyIn)
                            next = wrComplete;
                        else
                            next = write;
                    end

                    if (!busyIn) begin                        
                        bAddr = bAddr + 4;
                        mAddr = mAddr + 1;

                        if (txProgress > 0)
                            txProgress = txProgress - 1;
                        dataProgress = dataProgress + 1;
                    end
                end
            end
            wrComplete: begin
                if (dataProgress == blockS)
                    next = idle;
                else 
                    next = request;
            end
            error: begin
                if (!busErrorIn)
                    next = idle;
                
                txProgress = 0;
            end
            default: begin
                next = idle;
            end
        endcase
    end
    // output logic
    always @ (*) begin
        case (current)
            idle: begin
                requestOut          =  1'b0;
                addressDataOut      = 32'd0;
                byteEnablesOut      =  4'd0;
                burstSizeOut        =  8'd0;
                readNotWriteOut     =  1'b0;
                beginTransactionOut =  1'b0;
                endTransactionOut   =  1'b0;
                dataValidOut        =  1'b0;
            end
            request: begin
                requestOut          =  1'b1;
                addressDataOut      = 32'd0;
                byteEnablesOut      =  4'd0;
                burstSizeOut        =  8'd0;
                readNotWriteOut     =  1'b0;
                beginTransactionOut =  1'b0;
                endTransactionOut   =  1'b0;
                dataValidOut        =  1'b0;
            end
            granted: begin
                requestOut          = 1'b0;
                addressDataOut      = bAddr;
                byteEnablesOut      = readNotWriteReg ? 4'h0 : 4'hF;
                if (remaining(blockS, dataProgress) > burstS + 1)
                    burstSizeOut = burstS;
                else
                    burstSizeOut = remaining(blockS, dataProgress);
                readNotWriteOut     = readNotWriteReg;
                beginTransactionOut = 1'b1;
                endTransactionOut   = 1'b0;
                dataValidOut        = 1'b0;
            end
            read: begin
                requestOut          =  1'b0;
                addressDataOut      = 32'd0;
                byteEnablesOut      =  4'd0;
                burstSizeOut        =  8'd0;
                readNotWriteOut     =  1'b0;
                beginTransactionOut =  1'b0;
                endTransactionOut   =  1'b0;
                dataValidOut        =  1'b0;
            end
            rdComplete: begin
                requestOut          =  1'b0;
                addressDataOut      = 32'd0;
                byteEnablesOut      =  4'd0;
                burstSizeOut        =  8'd0;
                readNotWriteOut     =  1'b0;
                beginTransactionOut =  1'b0;
                endTransactionOut   =  1'b0;
                dataValidOut        =  1'b0;
            end
            write: begin
                requestOut          = 1'b0;
                addressDataOut      = mem[mAddr];
                byteEnablesOut      = 4'd0;
                burstSizeOut        = 8'd0;
                readNotWriteOut     = 1'b0;
                beginTransactionOut = 1'b0;
                endTransactionOut   = 1'b0;
                dataValidOut        = 1'b1; // TODO: SRAM latency?
            end
            wrComplete: begin
                requestOut          =  1'b0;
                addressDataOut      = 32'd0;
                byteEnablesOut      =  4'd0;
                burstSizeOut        =  8'd0;
                readNotWriteOut     =  1'b0;
                beginTransactionOut =  1'b0;
                endTransactionOut   =  1'b1;
                dataValidOut        =  1'b0;
            end
            error: begin
                requestOut          =  1'b0;
                addressDataOut      = 32'd0;
                byteEnablesOut      =  4'd0;
                burstSizeOut        =  8'd0;
                readNotWriteOut     =  1'b0;
                beginTransactionOut =  1'b0;
                endTransactionOut   =  1'b1;
                dataValidOut        =  1'b0;
            end
            default: begin
                requestOut          =  1'b0;
                addressDataOut      = 32'd0;
                byteEnablesOut      =  4'd0;
                burstSizeOut        =  8'd0;
                readNotWriteOut     =  1'b0;
                beginTransactionOut =  1'b0;
                endTransactionOut   =  1'b0;
                dataValidOut        =  1'b0;
            end
        endcase
    end
endmodule