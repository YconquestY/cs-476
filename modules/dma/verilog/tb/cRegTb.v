`include "../cReg.v"


`timescale 1ps/1ps

module cRegTb;
    reg        clock,
               reset;
    reg        p0WE,
               p1WE;
    reg  [7:0] p0DIn,
               p1DIn;
    wire [7:0] dO;

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

    cReg #(.width(8'd8)) dut
          (.clock(clock),
           .reset(reset),
           .p0WriteEnable(p0WE),
           .p0DataIn(p0DIn),
           .p1WriteEnable(p1WE),
           .p1DataIn(p1DIn),
           .dataOut(dO));
    initial begin
        p0WE = 1'b0;
        p1WE = 1'b0;
        p0DIn = 8'h00;
        p1DIn = 8'h00;
        #20;

        p0WE = 1'b1;
        p0DIn = 8'h01;
        #10;
        p0WE = 1'b0;
        #20;

        p1WE = 1'b1;
        p1DIn = 8'h02;
        #10;
        p1WE = 1'b0;
        #20;

        p0WE = 1'b1;
        p1WE = 1'b1;
        p0DIn = 8'h03;
        p1DIn = 8'h04;
        #10;
        p0WE = 1'b0;
        p1WE = 1'b0;
        #20;

        $finish;
    end

    initial begin
        $dumpfile("cReg.vcd");
        $dumpvars(0, cRegTb);
    end
endmodule