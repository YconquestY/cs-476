module ramDmaCi #(parameter [7:0] customId = 8'h00)
                 (input  wire        start,
                                     clock,
                                     reset,
         //         input  wire [31:0] valueA, // address
        //                             valueB, // data interface
        //          input  wire [ 7:0] ciN,
        //          output wire        done,
        //          output reg  [31:0] result,
                  // bus interface
                  input  wire        grantedIn,
                  input  wire [31:0] addressDataIn,
                  input  wire        endTransactionIn,
                                     dataValidIn,
                                     busErrorIn,
                                     busyIn,
                
                  input  wire [31:0] bAddrIn,//
                  input  wire [ 8:0] mAddrIn,//
                  input  wire [ 1:0] controlIn,//
                  input  wire [ 9:0] blockS,//
                  input  wire [ 7:0] burstS,//

                  
                  output reg        requestOut,
                  output reg [31:0] addressDataOut,
                  output reg [ 3:0] byteEnablesOut,
                  output reg [ 7:0] burstSizeOut,
                  output reg        readNotWriteOut,
                                    beginTransactionOut,
                                    endTransactionOut,
                                    dataValidOut,
                  output reg [3:0]  statusOut
                 );
    reg  [31: 0] mem [511:0]; // 512 32b words, i.e., 2KB
    reg [1:0] status;  
    reg [1:0] control; 
    reg [31:0] bAddr; // bus address
    reg [8:0]  mAddr; // memory address



    
    
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
            control      <=  controlIn; 
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
                
                /*else
                    next = idle;*/
                
                dataProgress = 0;
                mAddr = mAddrIn;
                bAddr = bAddrIn;
                statusOut = 4'd0;
            end
            request: begin
                if (busErrorIn)
                    next = error;
                else if (grantedIn)
                    next = granted;
            statusOut = 4'd1;
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
                        txProgress = burstS;  //是否要加一
                    else
                        txProgress = remaining(blockS, dataProgress);
                    // `dataProgress` reset in `idle` state
                end
                statusOut = 4'd2;
            end
          read: begin
                if (busErrorIn)
                    next = error;
                else if ((txProgress == 0) && endTransactionIn && !busyIn) 
                            next = rdComplete;
                else begin
                    next = read;
                            if (dataValidIn && !busyIn) begin
                                mem[mAddr] = addressDataIn;

                                bAddr = bAddr + 4;
                                mAddr = mAddr + 1;

                                if (txProgress > 0) begin
                                txProgress = txProgress - 1;
                                dataProgress = dataProgress + 1;
                                end
                            end
                        
                        end
                statusOut = 4'd3; 
                
            end 
            
            


            rdComplete: begin
                if (dataProgress == blockS)
                    next = idle;
                else
                    next = request;
                statusOut = 4'd4;
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
                statusOut = 4'd5;
            end
            wrComplete: begin
                if (dataProgress == blockS)
                    next = idle;
                else 
                    next = request;
                statusOut = 4'd6;
            end
            error: begin
                if (!busErrorIn)
                    next = idle;
                
                txProgress = 0;
                statusOut = 4'd7;
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