module key_level #(parameter integer CYCLES=1_485_000) (
    input wire clk,rst_n,key_n,
    output reg down
);
    localparam integer CW=CYCLES<2 ? 1 : $clog2(CYCLES);
    (* async_reg="true" *) reg [1:0] sync;
    reg [CW-1:0] count;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin sync<=3;count<=0;down<=0;end
        else begin
            sync<={sync[0],key_n};
            if((!sync[1])==down) count<=0;
            else if(count==CYCLES-1) begin down<=!sync[1];count<=0;end
            else count<=count+1'b1;
        end
    end
endmodule
