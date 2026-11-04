// Fixed compare/exchange network: no data-dependent sorting loop.
module median9 (
    input wire [71:0] i_pixels,
    output wire [7:0] o_median
);
    wire [7:0] value [0:9][0:8];
    genvar p, phase;
    generate
        for (p=0; p<9; p=p+1) begin : unpack
            assign value[0][p] = i_pixels[p*8 +: 8];
        end
        for (phase=0; phase<9; phase=phase+1) begin : network
            for (p=0; p<9; p=p+1) begin : column
                if ((p%2)==(phase%2) && p<8) begin : low
                    assign value[phase+1][p] = value[phase][p] < value[phase][p+1]
                                              ? value[phase][p] : value[phase][p+1];
                end else if (p>0 && ((p-1)%2)==(phase%2)) begin : high
                    assign value[phase+1][p] = value[phase][p] > value[phase][p-1]
                                              ? value[phase][p] : value[phase][p-1];
                end else begin : bypass
                    assign value[phase+1][p] = value[phase][p];
                end
            end
        end
    endgenerate
    assign o_median = value[9][4];
endmodule
