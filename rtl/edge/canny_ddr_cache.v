// Eight 128-bit write-back lines. 32 four-bit DFS tags per DDR word.
// One accepted pixel request at a time; dirty lines are committed before READY.
module canny_ddr_cache #(
    parameter integer PIXEL_BITS=21,
    parameter [31:0] BASE=32'h01000000
) (
    input wire clk,rst_n,invalidate,flush_start,
    input wire req_valid,req_write,
    input wire [PIXEL_BITS-1:0] req_addr,
    input wire [3:0] req_wdata,
    output reg req_ready,
    output reg [3:0] req_rdata,
    output wire busy,
    output reg flush_done,fault,
    output reg [31:0] hits,misses,
    output wire [31:0] awaddr,araddr,
    output wire awvalid,wvalid,wlast,bready,arvalid,rready,
    output wire [127:0] wdata,
    input wire awready,wready,bvalid,arready,rvalid,rlast,
    input wire [1:0] bresp,rresp,
    input wire [127:0] rdata
);
    localparam IDLE=0,LOOKUP=1,WRITE_A=2,WRITE_D=3,WRITE_B=4,
               READ_A=5,READ_D=6,ACCESS=7,RESPONSE=8,FLUSH=9;
    reg [3:0] state;
    reg [127:0] data[0:7];
    reg [PIXEL_BITS-6:0] tags[0:7];
    reg [7:0] valid,dirty;
    reg [2:0] victim,line;
    reg [3:0] flush_index;
    reg flushing,flush_pending,write_request;
    reg [PIXEL_BITS-6:0] word_address;
    reg [4:0] nibble;
    reg [3:0] write_tag;
    reg hit;
    reg [2:0] found;
    integer n;
    always @* begin
        hit=0;found=0;
        for(n=0;n<8;n=n+1) if(valid[n]&&tags[n]==word_address) begin hit=1;found=n;end
    end
    assign busy=state!=IDLE||flush_pending;
    assign awaddr=BASE+({{(37-PIXEL_BITS){1'b0}},tags[line]}<<4);
    assign araddr=BASE+({{(37-PIXEL_BITS){1'b0}},word_address}<<4);
    assign awvalid=state==WRITE_A;
    assign wvalid=state==WRITE_D;
    assign wlast=1'b1;
    assign wdata=data[line];
    assign bready=state==WRITE_B;
    assign arvalid=state==READ_A;
    assign rready=state==READ_D;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=IDLE;valid<=0;dirty<=0;victim<=0;line<=0;flush_index<=0;
            flushing<=0;flush_pending<=0;write_request<=0;word_address<=0;nibble<=0;write_tag<=0;
            req_ready<=0;req_rdata<=0;flush_done<=0;fault<=0;hits<=0;misses<=0;
        end else begin
            req_ready<=0;flush_done<=0;
            if(flush_start) flush_pending<=1;
            if(invalidate&&state==IDLE) begin valid<=0;dirty<=0;victim<=0;hits<=0;misses<=0;end
            case(state)
                IDLE:if(flush_pending) begin
                    flushing<=1;flush_index<=0;flush_pending<=0;state<=FLUSH;
                end else if(req_valid&&!invalidate) begin
                    word_address<=req_addr>>5;nibble<=req_addr[4:0];
                    write_request<=req_write;write_tag<=req_wdata;state<=LOOKUP;
                end
                LOOKUP:if(hit) begin line<=found;hits<=hits+1'b1;state<=ACCESS;end
                    else begin
                        line<=victim;victim<=victim+1'b1;misses<=misses+1'b1;
                        state<=valid[victim]&&dirty[victim] ? WRITE_A : READ_A;
                    end
                WRITE_A:if(awready) state<=WRITE_D;
                WRITE_D:if(wready) state<=WRITE_B;
                WRITE_B:if(bvalid) begin
                    if(bresp!=0) fault<=1;
                    dirty[line]<=0;
                    if(flushing) begin flush_index<=flush_index+1'b1;state<=FLUSH;end
                    else state<=READ_A;
                end
                READ_A:if(arready) state<=READ_D;
                READ_D:if(rvalid) begin
                    if(rresp!=0||!rlast) fault<=1;
                    data[line]<=rdata;tags[line]<=word_address;valid[line]<=1;dirty[line]<=0;state<=ACCESS;
                end
                ACCESS:begin
                    req_rdata<=data[line]>>(nibble*4);
                    if(write_request) begin data[line][nibble*4+:4]<=write_tag;dirty[line]<=1;end
                    req_ready<=1;state<=RESPONSE;
                end
                RESPONSE:state<=IDLE;
                FLUSH:if(flush_index==8) begin flushing<=0;flush_done<=1;state<=IDLE;end
                    else if(valid[flush_index[2:0]]&&dirty[flush_index[2:0]]) begin line<=flush_index[2:0];state<=WRITE_A;end
                    else flush_index<=flush_index+1'b1;
                default:begin fault<=1;state<=IDLE;end
            endcase
        end
    end
endmodule
