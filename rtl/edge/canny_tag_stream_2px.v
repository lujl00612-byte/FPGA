// Read-ahead of packed DFS tags. Key checks happen before the first active pair.
// FIFO starvation latches a fault and disables exact output until reset.
module canny_tag_stream_2px #(
    parameter integer WIDTH=1920,HEIGHT=1080,
    parameter integer PAIRS=WIDTH*HEIGHT/2,WORDS=(WIDTH*HEIGHT+31)/32
) (
    input wire clk,rst_n,in_vs,in_de,enable,source_valid,external_fault,
    input wire [45:0] source_key,
    input wire result_valid,reader_idle,
    input wire [45:0] result_key,ack_key,
    input wire [7:0] ack_sequence,
    output reg [7:0] request_sequence,
    input wire fifo_empty,fifo_valid,
    input wire [127:0] fifo_data,
    output wire fifo_read,
    output wire [1:0] edges,
    output wire exact_active,
    output reg fault
);
    reg vs_d,frame_started,frame_exact,stream_active,pending;
    reg [7:0] ack_seen;
    reg [127:0] head,tail;
    reg [1:0] count;
    reg [3:0] lane;
    reg [21:0] pair_index,issued,received;
    wire job_matches=enable&&source_valid&&result_valid&&source_key==result_key&&!fault;
    wire qualified=job_matches&&source_key==ack_key;
    assign exact_active=stream_active&&!fault&&(frame_started ? frame_exact : qualified&&count!=0);
    wire [7:0] tags=head>>(lane*8);
    assign edges=(exact_active&&in_de&&count!=0) ? {tags[7:4]>=3,tags[3:0]>=3} : 2'b00;
    assign fifo_read=stream_active&&!fifo_empty&&!pending&&count<2&&issued<WORDS;
    wire last_pair=in_de&&pair_index==PAIRS-1;
    wire pop=stream_active&&count!=0&&(fault||(in_de&&(lane==15||last_pair)));
    wire push=stream_active&&fifo_valid;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            vs_d<=0;frame_started<=0;frame_exact<=0;stream_active<=0;pending<=0;ack_seen<=0;
            request_sequence<=0;head<=0;tail<=0;count<=0;lane<=0;pair_index<=0;issued<=0;received<=0;fault<=0;
        end else begin
            if(external_fault) fault<=1;
            vs_d<=in_vs;
            if(in_vs&&!vs_d) begin
                frame_started<=0;frame_exact<=0;pair_index<=0;
                if(job_matches&&reader_idle&&!stream_active&&request_sequence==ack_sequence)
                    request_sequence<=request_sequence+1'b1;
            end
            if(ack_sequence!=ack_seen) begin
                if(frame_started) fault<=1;
                ack_seen<=ack_sequence;stream_active<=1;pending<=0;count<=0;lane<=0;issued<=0;received<=0;pair_index<=0;
            end else begin
                if(fifo_read) begin pending<=1;issued<=issued+1'b1;end
                if(fifo_valid) pending<=0;
                if(push) received<=received+1'b1;
                case({push,pop})
                    2'b10:begin if(count==0) head<=fifo_data;else tail<=fifo_data;count<=count+1'b1;end
                    2'b01:begin head<=tail;count<=count-1'b1;end
                    2'b11:begin if(count==1) head<=fifo_data;else begin head<=tail;tail<=fifo_data;end end
                    default:;
                endcase
                if(in_de) begin
                    pair_index<=pair_index+1'b1;
                    if(!frame_started) begin frame_started<=1;frame_exact<=qualified&&stream_active&&count!=0;end
                    if(stream_active) begin
                        if(count==0) fault<=1;
                        if(!fault) lane<=lane+1'b1;
                        if(last_pair&&!fault) begin stream_active<=0;count<=0;lane<=0;end
                    end
                end
                if(stream_active&&fault&&received==WORDS&&count==0&&!pending) stream_active<=0;
            end
        end
    end
endmodule
