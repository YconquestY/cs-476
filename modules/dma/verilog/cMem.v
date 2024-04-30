module cMem #(parameter width =  8'd32,
                        depth = 12'd512)
             (input wire clock,
                         reset,
              // port 0 connected to DMA controller
              input wire                     p0WriteEnable,
              input wire [$clog2(depth)-1:0] p0AddressIn,
              input wire [        width-1:0] p0DataIn,
              // port 1 connected to CPU
              input wire                     p1WriteEnable,
              input wire [$clog2(depth)-1:0] p1AddressIn,
              input wire [        width-1:0] p1DataIn,

              output reg [        width-1:0] p0DataOut,
              output reg [        width-1:0] p1DataOut);
    reg  [width-1:0] mem [depth-1:0];
    wire sameAddr;
    reg  [width-1:0] p1DataBuffer;
    integer i;
    
    assign sameAddr = (p0AddressIn == p1AddressIn);

    always @ (posedge clock) begin
        if (reset) begin
            for (i = 0; i < depth; i = i + 1) begin
                mem[i] <= {width{1'b0}};
            end
            p0DataOut <= {width{1'b0}};
            p1DataOut <= {width{1'b0}};
            p1DataBuffer <= {width{1'b0}};
        end
        // Port 1 (CPU, `p1…`) has higher prority than port 0 (DMA controller,
        // `p0…`).
        else begin
            if (p1WriteEnable)
                mem[p1AddressIn] <= p1DataIn;
            
            //p1DataBuffer <= mem[p1AddressIn];

            p0DataOut <= mem[p0AddressIn];
            p1DataOut <= p1DataBuffer; // 2-cycle read latency
        end
    end

    always @ (negedge clock) begin
        // reset done upon rising edge
        if (p0WriteEnable && p1WriteEnable) begin
            if (sameAddr) begin
                // port 1 already written upon rising edge
                p0DataOut <= mem[p0AddressIn];
            end
            else begin // write to different addresse: no race
                mem[p0AddressIn] <= p0DataIn;
                // port 1 already written upon rising edge

                p0DataOut <= p0DataIn;
                p1DataOut <= p1DataBuffer;
            end
            p1DataBuffer <= p1DataIn;
        end
        else if (p1WriteEnable) begin
            // port 1 already written upon rising edge
            p1DataBuffer <= p1DataIn;

            p0DataOut <= sameAddr ? p1DataIn
                                  : mem[p0AddressIn];
            p1DataOut <= p1DataBuffer;
        end
        else if (p0WriteEnable) begin
            mem[p0AddressIn] <= p0DataIn;

            if (sameAddr)
                p1DataBuffer <= p0DataIn;
            else
                p1DataBuffer <= mem[p1AddressIn];
            
            p0DataOut <= p0DataIn;
            p1DataOut <= p1DataBuffer;
        end
        else begin
            p1DataBuffer <= mem[p1AddressIn];
            
            p0DataOut <= mem[p0AddressIn];
            p1DataOut <= p1DataBuffer;
        end
    end
endmodule