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
    wire [8:0] addr;
    wire       writeen;
    wire       valid;

    assign addr    = valueA[8:0];
    assign writeen = valueA[9];
    // bus address: increment by 4
    reg         bAddrP0WriteEnable,
                bAddrP1WriteEnable;
    reg  [31:0] bAddrP0DataIn,
                bAddrP1DataIn;
    wire [31:0] bAddrDataOut;
    cReg #(.width(8'd32)) bAddr
          (.clock(clock),
           .reset(reset),
           
           .p0WriteEnable(bAddrP0WriteEnable),
           .p0DataIn(bAddrP0DataIn),
           
           .p1WriteEnable(bAddrP1WriteEnable),
           .p1DataIn(bAddrP1DataIn),
           
           .dataOut(bAddrDataOut));
    // memory address: increment by 1
    reg        mAddrP0WriteEnable,
               mAddrP1WriteEnable;
    reg  [8:0] mAddrP0DataIn,
               mAddrP1DataIn;
    wire [8:0] mAddrDataOut;
    cReg #(.width(8'd9)) mAddr
          (.clock(clock),
           .reset(reset),
           
           .p0WriteEnable(mAddrP0WriteEnable),
           .p0DataIn(mAddrP0DataIn),
           
           .p1WriteEnable(mAddrP1WriteEnable),
           .p1DataIn(mAddrP1DataIn),
           
           .dataOut(mAddrDataOut));
    // SRMA of 512 32b words, i.e., 2KB
    reg         memP0WriteEnable,
                memP1WriteEnable;
    reg  [ 8:0] memP0AddressIn,
                memP1AddressIn;
    reg  [31:0] memP0DataIn,
                memP1DataIn;
    wire [31:0] memP0DataOut,
                memP1DataOut;
    cMem #(.width( 8'd32),
           .depth(12'd512)) mem
          (.clock(clock),
           .reset(reset),
           
           .p0WriteEnable(memP0WriteEnable),
           .p0AddressIn(memP0AddressIn),
           .p0DataIn(memP0DataIn),
           
           .p1WriteEnable(memP1WriteEnable),
           .p1AddressIn(memP1AddressIn),
           .p1DataIn(memP1DataIn),
           
           .p0DataOut(memP0DataOut),
           .p1DataOut(memP1DataOut));
    // CPU-side port
    reg         port1RdDone;
    wire        port1WrDone;
    reg  [31:0] port1Result;

    assign valid = valueA[31:10] == 0;
    assign port1WrDone = !reset && start && valid && (ciN == customId) && writeen;

    always @ (posedge clock) begin
        if (reset) begin
            memP1WriteEnable <=  1'b0;
            memP1AddressIn   <=  9'd0;
            memP1DataIn      <= 32'd0;

            port1RdDone <= 1'b0;
            port1Result <= 32'd0;
        end
        else if (start && valid && (ciN == customId)) begin
            if (writeen) begin // write
                memP1WriteEnable <= 1'b1;
                memP1AddressIn   <= addr;
                memP1DataIn      <= valueB;

                port1RdDone <= 1'b0;
                port1Result <= 32'd0;
            end
            else begin // read
                memP1WriteEnable <= 1'b0;
                memP1AddressIn   <= addr;
                memP1DataIn      <= 32'd0;

                port1RdDone <= 1'b1;
                port1Result <= memP1DataOut; // 2-cycle read latency
            end
        end
        else begin
            memP1WriteEnable <=  1'b0;
            memP1AddressIn   <=  9'd0;
            memP1DataIn      <= 32'd0;

            port1RdDone <=  1'b0;
            port1Result <= 32'd0;
        end
    end
    // DMA-side port
    reg         port2RdDone;
    wire        port2WrDone;
    reg  [31:0] port2Result;
    wire [ 2:0] map;    // register map
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
    assign port2WrDone = !reset && start && (ciN == customId) && writeen && !bAddrP1WriteEnable
                                                                         && !mAddrP1WriteEnable;
    always @ (negedge clock) begin
        if (reset) begin
            bAddrP0WriteEnable <= 1'b0;
            mAddrP0WriteEnable <= 1'b0;

            bAddrP0DataIn <= 32'd0;
            mAddrP0DataIn <=  9'd0;

            memP0WriteEnable <=  1'b0;
            memP0AddressIn   <=  9'd0;
            memP0DataIn      <= 32'd0;

            port2RdDone <= 1'b0;
            port2Result <= 32'd0;
            
            blockS  <= 10'd0;
            burstS  <=  8'd0;
            status  <=  2'd0;
            control <=  2'd0;
        end
        else if (start && (ciN == customId)) begin
            if (writeen) begin // write
                case (map)
                    3'b000: begin // write to SRAM
                        // write already done upone rising edge
                    end
                    3'b001: begin // write bus start address
                        bAddrP0WriteEnable <= 1'b1;
                        bAddrP0DataIn      <= valueB;
                    end
                    3'b010: begin // write SRAM start address
                        mAddrP0WriteEnable <= 1'b1;
                        mAddrP0DataIn      <= valueB[8:0];
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
                port2RdDone <= 1'b0;
                port2Result <= 32'd0;
            end
            else begin // read
                case (map)
                    3'b000: begin // read from SRAM
                        memP0WriteEnable <= 1'b0;
                        memP0AddressIn   <= addr;
                        memP0DataIn      <= 32'd0;

                        port2Result <= memP0DataOut;
                    end
                    3'b001: begin // read bus start address
                        bAddrP0WriteEnable <=  1'b0;
                        bAddrP0DataIn      <= 32'd0;

                        port2Result <= bAddrDataOut;
                    end
                    3'b010: begin // read SRAM start address
                        mAddrP0WriteEnable <=  1'b0;
                        mAddrP0DataIn      <= 32'd0;

                        port2Result <= {23'd0, mAddrDataOut};
                    end
                    3'b011: begin // read block size
                        port2Result <= {22'd0, blockS};
                    end
                    3'b100: begin // read burst size
                        port2Result <= {24'd0, burstS};
                    end
                    3'b101: begin // read status register
                        port2Result <= {30'd0, status};
                    end
                    default: begin
                        // do nothing
                    end
                endcase
                port2RdDone <= 1'b1;
            end
        end
        else begin
            bAddrP0WriteEnable <=  1'b0;
            bAddrP0DataIn      <= 32'd0;

            mAddrP0WriteEnable <=  1'b0;
            mAddrP0DataIn      <= 32'd0;

            port2RdDone <= 1'b0;
            port2Result <= 32'd0;
        end
    end

    assign done   = port1RdDone || port2RdDone || port1WrDone || port2WrDone;
    assign result = clock ? port1Result
                          : 32'd321;
    /*
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
    reg       dmaUpdatingMem,
              dmaUpdatingBAddr,
              dmaUpdatingMAddr;

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
        case (current)
            idle: begin
                if (blockS > 0 && (control[1] ^ control[0])) begin // `burstS` is always positive.
                    next = request;
                    readNotWriteReg = control == 2'b01; // only set, never reset
                end
                else
                    next = idle;
                
                dataProgress = 0;
            end
            request: begin
                if (busErrorIn)
                    next = error;
                else if (grantedIn)
                    next = granted;
                else
                    next = request;
            end
            granted: begin
                if (busErrorIn)
                    next = error;
                else begin
                    if (readNotWriteReg) begin // read from bus
                        next = read;
                        dmaUpdatingMem = 1'b1;
                    end
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
                    if (txProgress > 0)
                        next = read;
                    else if (txProgress == 0) begin
                        if (endTransactionIn && !busyIn) begin
                            next = rdComplete;
                            dmaUpdatingMem = 1'b0;
                        end
                        //else if (dataValidIn && !busyIn)
                        //    next = read;
                        else
                            next = read;
                    end
                    else // impossible
                        next = error;

                    if (dataValidIn && !busyIn) begin
                        //mem[mAddr] = addressDataIn;

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
                    if (txProgress > 0)
                        next = write;
                    else if (txProgress == 0) begin
                        if (!busyIn)
                            next = wrComplete;
                        else
                            next = write;
                    end
                    else // impossible
                        next = error;

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
                else
                    next = error;
                
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
    */
endmodule