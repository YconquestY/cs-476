module cReg #(parameter width = 8'd32)
             (input  wire             clock,
                                      reset,
              input  wire             p0WriteEnable,
              input  wire [width-1:0] p0DataIn,
              
              input  wire             p1WriteEnable,
              input  wire [width-1:0] p1DataIn,
              
              output reg  [width-1:0] dataOut);
    reg [width-1:0] _reg;

    always @ (negedge clock) begin
        if (reset) begin
            _reg <= {width{1'b0}};
            dataOut <= {width{1'b0}};
        end
        else begin
            // `dataOut` must be assigned in all branches for latency concern.
            // Port 1 (FSM, `p1…`) has higher priority than port 0 (DMA
            // controller`p0…`).
            if (p1WriteEnable) begin
                _reg <= p1DataIn;
                dataOut <= p1DataIn;
            end
            else if (p0WriteEnable) begin
                _reg <= p0DataIn;
                dataOut <= p0DataIn;
            end
            else
                dataOut <= _reg;
        end
    end
endmodule