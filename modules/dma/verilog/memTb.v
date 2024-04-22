`timescale 1ps/1ps

module memTb;
    reg        start,
               clock,
               reset;
    reg [31:0]  valueA,
               _valueA,
                valueB,
               _valueB;
    reg [ 7:0] ciN;
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
    initial begin
        start  <= 1'b0;
        ciN    <= 8'd0;
        valueA <= 32'd0;
        valueB <= 0;
        #20;
        // write to SRAM
        _valueA <= 32'h000003FE;
        _valueB <= 477;

        start  <= 1'b1;
        ciN    <= 8'd123;
        valueA <= 32'h000003FF;
        valueB <= 476;
        #5;
        start  <= 1'b0;
        ciN    <= 8'd0;
        valueA <= 0;
        valueB <= 0;
        #5;
        repeat(4) begin
            _valueA <= _valueA - 1;
            _valueB <= _valueB + 1;

            start  <= 1'b1;
            ciN    <= 8'd123;
            valueA <= _valueA;
            valueB <= _valueB;
            #5;
            start  <= 1'b0;
            ciN    <= 8'd0;
            valueA <= 0;
            valueB <= 0;
            #5;
        end

        start  <= 1'b0;
        ciN    <= 8'd0;
        valueA <= 0;
        valueB <= 0;
        #20;
        // read from SRAM
        repeat(5) begin
            start  <= 1'b1;
            ciN    <= 8'd123;
            valueA <= _valueA;
            valueB <= 0;
            #5;
            start  <= 1'b0;
            ciN    <= 8'd0;
            valueA <= 0;
            valueB <= 0;
            #5;
            valueA <= valueA + 1;
        end

        start  <= 1'b0;
        ciN    <= 8'd0;
        valueA <= 0;
        valueB <= 0;
        #20;

        $finish;
    end

    initial begin
        $dumpfile("mem.vcd");
        $dumpvars(1, dut);
    end
endmodule
