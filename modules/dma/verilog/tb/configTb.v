`include "../ramDmaCi.v"


`timescale 1ps/1ps

module configTb;
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
    initial begin
        start  <= 1'b0;
        ciN    <= 8'd0;
        valueA <= 32'd0;
        valueB <= 0;
        #20;
        // write to `mem[511]`
        start  <= 1'b1;
        ciN    <= 8'd123;
        valueA <= 32'h000003FF;
        valueB <= 476;
        #10;
        // write bus start address
        valueA <= 32'h00000600;
        valueB <= 420;
        #10;
        // write SRAM start address
        valueA <= 32'h00000A00;
        valueB <= 440;
        #10;
        // write block size
        valueA <= 32'h00000E00;
        valueB <= 470;
        #10;
        // write burst size
        valueA <= 32'h00001200;
        valueB <= 234;
        #10;

        // read `mem[511]`
        valueA <= 32'h000001FF;
        valueB <= 0;
        #20;
        // read bus start address
        valueA <= 32'h00000400;
        #10;
        // read SRAM start address
        valueA <= 32'h00000800;
        #10;
        // read block size
        valueA <= 32'h00000C00;
        #10;
        // read burst size
        valueA <= 32'h00001000;
        #10;
        // read status register
        valueA <= 32'h00001400;
        #10;

        // write to `mem[511]`
        start  <= 1'b1;
        ciN    <= 8'd123;
        valueA <= 32'h000003FF;
        valueB <= 1;
        #10;
        // write bus start address
        valueA <= 32'h00000600;
        valueB <= 2;
        #10;
        // write SRAM start address
        valueA <= 32'h00000A00;
        valueB <= 3;
        #10;
        // write block size
        valueA <= 32'h00000E00;
        valueB <= 4;
        #10;
        // write burst size
        valueA <= 32'h00001200;
        valueB <= 5;
        #10;

        start  <= 1'b0;
        ciN    <= 8'd0;
        valueA <= 0;
        valueB <= 0;
        #20;

        $finish;
    end
    initial begin
        $dumpfile("config.vcd");
        $dumpvars(0, configTb);
        $dumpvars(1, dut);
    end
endmodule