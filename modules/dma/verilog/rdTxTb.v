`timescale 1ps/1ps

module rdTxTb;
    reg        start,
               clock,
               reset;
    reg [31:0] valueA,
               valueB;
    reg  [ 7:0] ciN;
    wire        o_done;
    wire [31:0] o_result;
    initial begin
        reset = 1'b1;
        clock = 1'b1;
        repeat(4) begin
            #5 clock = ~clock; // 10 ps per cycle
        end
        reset = 1'b0;
        forever begin
            #5 clock = ~clock;
        end
    end

    ramDmaCi #(.customId(123)) dut
              (.start(start),
               .clock(clock),
               .reset(reset),
               .valueA(valueA),
               .valueB(valueB),
               .ciN(ciN),
               .done(o_done),
               .result(o_result),
               
               .grantedIn(1'b0),
               .addressDataIn(32'd0),
               .endTransactionIn(1'b0),
               .dataValidIn(1'b0),
               .busErrorIn(1'b0),
               .busyIn(1'b0),
               
               .requestOut(),
               .addressDataOut(),
               .byteEnablesOut(),
               .burstSizeOut(),
               .readNotWriteOut(),
               .beginTransactionOut(),
               .endTransactionOut(),
               .dataValidOut());
endmodule