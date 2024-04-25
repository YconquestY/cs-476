`timescale 1ps / 1ps
`include "State.v"

module ramDmaCi_tb;

    initial begin
        reset = 1'b1;
        clock = 1'b0;
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
    reg [31:0] addressDataIn, bAddrIn;
    reg [8:0] mAddrIn;
    reg [1:0] controlIn;
    reg [9:0] blockS;
    reg [7:0] burstS;
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
        .grantedIn(grantedIn),
        .addressDataIn(addressDataIn),
        .endTransactionIn(endTransactionIn),
        .dataValidIn(dataValidIn),
        .busErrorIn(busErrorIn),
        .busyIn(busyIn),
        .bAddrIn(bAddrIn),
        .mAddrIn(mAddrIn),
        .controlIn(controlIn),
        .blockS(blockS),
        .burstS(burstS),
        .requestOut(requestOut),
        .addressDataOut(addressDataOut),
        .byteEnablesOut(byteEnablesOut),
        .burstSizeOut(burstSizeOut),
        .readNotWriteOut(readNotWriteOut),
        .beginTransactionOut(beginTransactionOut),
        .endTransactionOut(endTransactionOut),
        .dataValidOut(dataValidOut),
        .statusOut(statusOut)
    );


    initial begin
        // Test all states
        
        // Idle state to request state
        start = 0;
        addressDataIn = 0;
        bAddrIn = 0;
        mAddrIn = 0;
        controlIn = 2'b10;
        blockS = 5;
        burstS = 3;
        endTransactionIn = 0;
        dataValidIn = 0;
        busErrorIn = 0;
        busyIn = 0;
        grantedIn = 0;
        $monitor("Current state: %s", dut.current);
        #30;

        // Granted state
        grantedIn = 1;
        $monitor("Current state: %s", dut.current);
        #10;
        
        // write state
        grantedIn = 0;
        dataValidIn = 1;
        #10;
        addressDataIn = 32'h00000001;
        #10
        addressDataIn = 32'h00000002;
        #10
        addressDataIn = 32'h00000003;
        #10
        addressDataIn = 32'h00000004;
        #10
        addressDataIn = 32'h00000005;
        
        $monitor("Current state: %s", dut.current);
        #10;
        
        
        // RdComplete state
        endTransactionIn = 1;
        busyIn = 0;
        controlIn = 2'b01;
        $monitor("Current state: %s", dut.current);
        #10;

        // request state to granted state
        grantedIn = 1;
        $monitor("Current state: %s", dut.current);
        #10;
        
        //Write state
        addressDataIn = 32'h00000001;
        #10
        addressDataIn = 32'h00000000;
        #10

        
        // Error state
        busErrorIn = 1;
        $monitor("Current state: %s", dut.current);
        #10;
        
        // End simulation
        #1000 $finish;
    end

        // Initial stimulus
    initial begin
        $dumpfile("statetbWRITE.vcd");
        $dumpvars(1,dut);

    end

endmodule
