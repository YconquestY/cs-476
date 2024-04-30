`include "../ramDmaCi.v"


`timescale 1ps / 1ps

module wrTb;
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
    
    // Signals
    reg start, clock, reset;
    reg [31:0] addressDataIn,
                valueA,  valueB,
               _valueA, _valueB;
    reg [7:0] ciN;
    reg grantedIn, endTransactionIn, dataValidIn, busErrorIn, busyIn;

    
    wire requestOut, beginTransactionOut, endTransactionOut, dataValidOut;
    wire [31:0] addressDataOut;
    wire [3:0] byteEnablesOut;
    wire [7:0] burstSizeOut;
    wire readNotWriteOut;
    wire [3:0] statusOut;
    
    // Instantiate the module under test
    ramDmaCi #(.customId(123)) dut(
        .start(start),
        .clock(clock),
        .reset(reset),

        .valueA(valueA),
        .valueB(valueB),
        .ciN(ciN),
        .done(),
        .result(),

        .grantedIn(grantedIn),
        .addressDataIn(addressDataIn),
        .endTransactionIn(endTransactionIn),
        .dataValidIn(dataValidIn),
        .busErrorIn(busErrorIn),
        .busyIn(busyIn),

        .requestOut(requestOut),
        .addressDataOut(addressDataOut),
        .byteEnablesOut(byteEnablesOut),
        .burstSizeOut(burstSizeOut),
        .readNotWriteOut(readNotWriteOut),
        .beginTransactionOut(beginTransactionOut),
        .endTransactionOut(endTransactionOut),
        .dataValidOut(dataValidOut)
    );


    initial begin
        // Idle state to request state
        start = 0;
        reset = 1;
        valueA = 0;
        valueB = 0;
        ciN = 0;
        grantedIn = 0;
        addressDataIn = 0;
        endTransactionIn = 0;
        dataValidIn = 0;
        busErrorIn = 0;
        busyIn = 0;   

        _valueA = 32'h000003FF;
        _valueB = 476;
        #20;

        // Write `mem[511..507]`
        repeat(5) begin
            _valueA <= _valueA - 1;
            _valueB <= _valueB + 1;

            start = 1;
            ciN = 123;
            valueA = _valueA;
            valueB = _valueB;
            #10;
        end

        // Write bus start address
        valueA = 32'h00000600;
        valueB = 420;
        #10;

        // Write SRAM start address
        valueA = 32'h00000A00;
        valueB = 507;
        #10;

        // Write block size
        valueA = 32'h00000E00;
        valueB = 5;
        #10;

        // Write burst size
        valueA = 32'h00001200;
        valueB = 1; // actually 2
        #10;

        // Write control
        valueA = 32'h00001600;
        valueB = 2;
        #10;

        start = 0;
        ciN = 0;
        valueA = 0;
        valueB = 0;
        #30;

        grantedIn = 1;
        #10;

        grantedIn = 0;
        #1000;
        
        $finish;
    end

    initial begin
        $dumpfile("wr.vcd");
        $dumpvars(0, wrTb);
    end
endmodule
