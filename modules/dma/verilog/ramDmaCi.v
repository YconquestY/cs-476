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
    wire       writeen,
               valid,
               increment;

    assign addr      = valueA[8:0];
    assign writeen   = valueA[9];
    assign increment = !busErrorIn && !busyIn && memTraffic;
    // bus address: increment by 4
    wire [31:0] bAddrDataOut;
    cReg #(.width(8'd32)) bAddr
          (.clock(clock),
           .reset(reset),
           // port 0 connected to CPU
           .p0WriteEnable(port2WrDone && map == 3'b001),
           .p0DataIn(valueB),
           // port 1 connected to DMA FSM
           .p1WriteEnable(increment),
           .p1DataIn(bAddrDataOut + 32'd4),
           
           .dataOut(bAddrDataOut));
    
    // memory address: increment by 1
    wire [8:0] mAddrDataOut;
    cReg #(.width(8'd9)) mAddr
          (.clock(clock),
           .reset(reset),
           // port 0 connected to CPU
           .p0WriteEnable(port2WrDone && (map == 3'b010)),
           .p0DataIn(valueB[8:0]),
           // port 1 connected to DMA FSM
           .p1WriteEnable(increment),
           .p1DataIn(mAddrDataOut + 9'd1),
           
           .dataOut(mAddrDataOut));
    // SRAM of 512 32b words, i.e., 2KB
    wire [31:0] memP0DataOut,
                memP1DataOut;
    cMem #(.width( 8'd32),
           .depth(12'd512)) mem
          (.clock(clock),
           .reset(reset),
           // port 0 connected to DMA controller
           .p0WriteEnable(memTraffic && !busErrorIn && dataValidIn && !busyIn),
           .p0AddressIn(memTraffic ? mAddrDataOut : addr),
           .p0DataIn(addressDataIn),
           // port 1 connected to CPU
           .p1WriteEnable(port1WrDone),
           .p1AddressIn(addr),
           .p1DataIn(valueB),
           
           .p0DataOut(memP0DataOut),
           .p1DataOut(memP1DataOut));
    // CPU-side port
    reg         port1RdDone;
    wire        port1WrDone;

    assign valid = valueA[31:10] == 0;
    assign port1WrDone = !reset && start && valid && (ciN == customId) && writeen;

    always @ (posedge clock) begin
        if (reset) begin
            port1RdDone <= 1'b0;
        end
        else if (start && valid && (ciN == customId)) begin
            if (writeen) begin // write
                port1RdDone <= 1'b0;
            end
            else begin // read: 2-cycle latency
                port1RdDone <= 1'b1;
            end
        end
        else begin
            port1RdDone <=  1'b0;
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
    assign port2WrDone = !reset && start && (ciN == customId) && writeen && !increment;
    always @ (negedge clock) begin
        if (reset) begin
            port2RdDone <= 1'b0;
            
            blockS  <= 10'd0;
            burstS  <=  8'd0;
            status  <=  2'd0;
            control <=  2'd0;
        end
        else if (start && (ciN == customId)) begin
            if (writeen) begin // write
                case (map)
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
                        /* do nothing
                         *
                         * 3'b000: write already done upon rising edge
                         * 3'b001: bus address implicitly written
                         * 3'b010: SRAM address implicitly written
                         */
                    end
                endcase
                port2RdDone <= 1'b0;
            end
            else begin // read
                // `port2Result` is populated below.
                port2RdDone <= 1'b1;
            end
        end
        else begin
            port2RdDone <= 1'b0;
        end
    end

    assign done = port1RdDone || port2RdDone || port1WrDone || port2WrDone;
    always @ (*) begin
        case(map)
            3'b000: port2Result = memP0DataOut;
            3'b001: port2Result = bAddrDataOut;
            3'b010: port2Result = {23'd0, mAddrDataOut};
            3'b011: port2Result = {22'd0, blockS};
            3'b100: port2Result = {24'd0, burstS};
            3'b101: port2Result = {30'd0, status};
            default:
                port2Result = 32'd0;
        endcase
    end
    
    assign result = (port1WrDone || port2WrDone) ? 32'd0
                                                 : port2RdDone ? port2Result
                                                               : port1RdDone ? memP1DataOut
                                                               : 32'd0;
    /*
    always @ (*) begin
        if (port1WrDone || port2WrDone)
            result = 32'd0;
        else begin
            if (port2RdDone)
                result = port2Result;
            if (port1RdDone)
                result = memP1DataOut;
        end
    end
    */
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
    reg       readNotWriteReg, // data transfer direction
              memTraffic;      // whether there is ongoing SRAM traffic
    // state transition
    always @ (negedge clock) begin
        if (reset)
            current <= idle;
        else begin
            current <= next;

            if (current == 3'd3 || current == 3'd5) begin
                if (txProgress > 0)
                    txProgress <= txProgress - 1;
                dataProgress <= dataProgress + 1;
            end
        end
    end
    // helper function to computing number of words to be transferred
    /*
    function [9:0] remaining;
    input [9:0] blockS,
                dataProgress;
    begin
        remaining = blockS - dataProgress;
    end
    endfunction
    */
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
                
                txProgress = 0;
                dataProgress = 0;

                memTraffic = 1'b0;
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
                    end
                    else // write to bus
                        next = write;

                    if (blockS - dataProgress > burstS + 1)
                        txProgress = burstS;
                    else
                        txProgress = blockS - dataProgress;
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
                            memTraffic = 1'b0;
                        end
                        //else if (dataValidIn && !busyIn)
                        //    next = read;
                        else
                            next = read;
                    end
                    else // impossible
                        next = error;

                    if (dataValidIn && !busyIn) begin
                        // `addressDataIn` written to `mem[mAddr]`

                        //bAddr = bAddr + 4;
                        //mAddr = mAddr + 1;

                        //if (txProgress > 0)
                        //    txProgress = txProgress - 1;
                        //dataProgress = dataProgress + 1;
                    end
                end
                memTraffic = 1'b1;
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
                        if (!busyIn) begin
                            next = wrComplete;
                            memTraffic = 1'b0;
                        end
                        else
                            next = write;
                    end
                    else // impossible
                        next = error;

                    if (!busyIn) begin                        
                        //bAddr = bAddr + 4;
                        //mAddr = mAddr + 1;

                        //if (txProgress > 0)
                        //    txProgress = 234;//txProgress - 1;
                        //dataProgress = dataProgress + 1;
                    end
                end
                memTraffic = 1'b1;
            end
            wrComplete: begin
                if (dataProgress == blockS)
                    next = idle;
                else 
                    next = request;
                memTraffic = 1'b0;
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
                addressDataOut      = bAddrDataOut;
                byteEnablesOut      = readNotWriteReg ? 4'h0 : 4'hF;
                if (blockS - dataProgress > burstS + 1)
                    burstSizeOut = burstS;
                else
                    burstSizeOut = blockS - dataProgress;
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
                addressDataOut      = memP0DataOut;
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