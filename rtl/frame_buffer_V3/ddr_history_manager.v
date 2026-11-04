// Four native-RAW DDR slots. Only acknowledged, complete frames become readable.
// Replay operates on the held input frame, so changed manual settings can recompute it.
module ddr_history_manager #(
    parameter integer ADDR_WIDTH=32,
    parameter [ADDR_WIDTH-1:0] START_ADDR=0,
    parameter integer SLOT_SHIFT=22,
    parameter integer AXI_BYTES=32
) (
    input wire clk,rst_n,
    input wire write_request,write_done,write_error,
    input wire [24:0] write_beats,
    input wire read_request,read_done,read_error,
    input wire freeze_request,
    input wire [7:0] step_sequence,
    input wire step_older,
    output reg write_issue,read_issue,
    output reg [ADDR_WIDTH-1:0] write_address,read_address,
    output reg [24:0] read_beats,
    output reg write_busy,read_busy,
    output reg read_valid,
    output reg [31:0] read_frame_id,
    output reg [1:0] replay_age,
    output wire memory_ready,
    output wire [2:0] history_count,
    output reg fault
);
    reg [3:0] valid;
    reg [31:0] ids[0:3];
    reg [24:0] lengths[0:3];
    reg [31:0] next_id,pending_id;
    reg [24:0] pending_beats;
    reg [1:0] write_slot,read_slot;
    reg frozen_at_read;
    reg [7:0] step_seen;
    assign memory_ready=|valid;
    assign history_count={2'd0,valid[0]}+valid[1]+valid[2]+valid[3];
    integer i,j,k;
    reg [2:0] rank[0:3];
    reg [31:0] ages[0:3];
    reg [2:0] wanted,current_rank;
    reg [1:0] selected,write_selected;
    reg selected_ok,write_ok;
    reg [31:0] oldest;
    always @(*) begin
        for(i=0;i<4;i=i+1) begin
            ages[i]=next_id-ids[i];rank[i]=0;
            for(j=0;j<4;j=j+1)
                if(valid[j]&&(next_id-ids[j])<(next_id-ids[i])) rank[i]=rank[i]+1'b1;
        end
        current_rank=read_valid&&valid[read_slot] ? rank[read_slot] : 0;
        wanted=0;
        if(freeze_request&&frozen_at_read) begin
            wanted=current_rank;
            if(step_sequence!=step_seen) begin
                if(step_older&&wanted+1<history_count) wanted=wanted+1'b1;
                else if(!step_older&&wanted>0) wanted=wanted-1'b1;
            end
        end
        selected=read_slot;selected_ok=0;
        for(i=0;i<4;i=i+1) if(valid[i]&&rank[i]==wanted) begin selected=i;selected_ok=1;end
        // Freeze holds the chosen slot even if an already admitted capture completes.
        if(freeze_request&&frozen_at_read&&step_sequence==step_seen&&read_valid&&valid[read_slot]) begin
            selected=read_slot;selected_ok=1;
        end
        write_selected=0;write_ok=0;oldest=0;
        for(i=0;i<4;i=i+1) begin
            if(!(((read_busy||freeze_request)&&read_valid&&i==read_slot)||
                 (read_request&&selected_ok&&i==selected))) begin
                if(!write_ok||!valid[i]||(valid[write_selected]&&ages[i]>oldest)) begin
                    write_selected=i;write_ok=1;oldest=ages[i];
                end
            end
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            valid<=0;next_id<=1;pending_id<=0;pending_beats<=0;write_slot<=0;read_slot<=0;
            frozen_at_read<=0;step_seen<=0;write_issue<=0;read_issue<=0;write_busy<=0;read_busy<=0;
            write_address<=START_ADDR;read_address<=START_ADDR;read_beats<=0;read_valid<=0;read_frame_id<=0;
            replay_age<=0;fault<=0;
            for(k=0;k<4;k=k+1) begin ids[k]<=0;lengths[k]<=0;end
        end else begin
            write_issue<=0;read_issue<=0;
            if(write_done&&write_busy) begin
                write_busy<=0;
                if(!write_error) begin valid[write_slot]<=1;ids[write_slot]<=pending_id;lengths[write_slot]<=pending_beats;end
                else fault<=1;
            end
            if(read_done&&read_busy) begin read_busy<=0;if(read_error) begin fault<=1;read_valid<=0;end end
            if(write_request) begin
                if(!write_busy&&write_ok&&write_beats!=0&&write_beats<=(1<<SLOT_SHIFT)/AXI_BYTES) begin
                    valid[write_selected]<=0;write_slot<=write_selected;
                    pending_id<=next_id;next_id<=next_id+1'b1;pending_beats<=write_beats;
                    write_address<=START_ADDR+({{(ADDR_WIDTH-2){1'b0}},write_selected}<<SLOT_SHIFT);
                    write_busy<=1;write_issue<=1;
                end else fault<=1;
            end
            if(read_request) begin
                if(!read_busy&&selected_ok) begin
                    read_slot<=selected;read_frame_id<=ids[selected];read_beats<=lengths[selected];
                    read_address<=START_ADDR+({{(ADDR_WIDTH-2){1'b0}},selected}<<SLOT_SHIFT);
                    read_valid<=1;read_busy<=1;read_issue<=1;replay_age<=rank[selected];
                    frozen_at_read<=freeze_request;step_seen<=step_sequence;
                end else if(read_busy) fault<=1;
            end
        end
    end
endmodule
