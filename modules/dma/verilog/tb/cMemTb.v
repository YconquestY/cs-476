`include "../cMem.v"


`timescale 1ps/1ps

module cMemTb;
    reg         clock,
                reset;
    reg         p0WE,
                p1WE;
    reg  [ 8:0] p0AIn,
                p1AIn;
    reg  [31:0] p0DIn,
                p1DIn;
    wire [31:0] p0DO,
                p1DO;
    initial begin
        reset = 1'b1;
        clock = 1'b1;
        repeat (4) begin
            #5 clock = ~clock; // 10 ps per cycle
        end
        reset = 1'b0;
        forever begin
            #5 clock = ~clock;
        end
    end

    cMem #(.width( 8'd32),
           .depth(12'd512)) dut
          (.clock(clock),
           .reset(reset),

           .p0WriteEnable(p0WE),
           .p0AddressIn(p0AIn),
           .p0DataIn(p0DIn),
           
           .p1WriteEnable(p1WE),
           .p1AddressIn(p1AIn),
           .p1DataIn(p1DIn),

           .p0DataOut(p0DO),
           .p1DataOut(p1DO));
    initial begin
        p0WE = 1'b0;
        p0AIn = 9'd0;
        p0DIn = 32'd0;

        p1WE = 1'b0;
        p1AIn = 9'd0;
        p1DIn = 32'd0;
        #20;
        // write port 0
        p0WE = 1'b1;
        p0AIn = 9'd476;
        p0DIn = 32'd420;

        p1AIn = 9'd476;
        #10;
        //
        p0WE = 1'b0;
        #20;
        // write port 1
        p0AIn = 9'd470;

        p1WE = 1'b1;
        p1AIn = 9'd470;
        p1DIn = 32'd440;
        #10;
        //
        p1WE = 1'b0;
        #10;
        p1AIn = 9'd476;
        #10;
        // concurrently write to same address
        p0WE = 1'b1;
        p0AIn = 9'd471;
        p0DIn = 32'd629;

        p1WE = 1'b1;
        p1AIn = 9'd471;
        p1DIn = 32'd626;
        #10;
        //
        p0WE = 1'b0;
        p1WE = 1'b0;
        #20;

        // concurrently write to different addresses
        p0WE = 1'b1;
        p0AIn = 9'd451;
        p0DIn = 32'd522;

        p1WE = 1'b1;
        p1AIn = 9'd453;
        p1DIn = 32'd510;
        #10;
        //
        p0WE = 1'b0;
        p0AIn = 9'd453;

        p1WE = 1'b0;
        p1AIn = 9'd451;
        #20;

        $finish;
    end

    initial begin
        $dumpfile("cMemTb.vcd");
        $dumpvars(0, cMemTb);
    end
endmodule