// Serialized coherent detection record on the existing 16-bit LA colour probes.
// Version1: 16 words, checksum15. Feature version2: 32 words, checksum31; both begin A53C.
module detection_telemetry #(parameter integer FEATURE_PACKET=0)(
    input wire clk,rst_n,result_valid,source_valid,cal_done,busy,
    input wire [3:0] kind,
    input wire [31:0] result_frame,source_frame,
    input wire [14:0] config_id,
    input wire [10:0] x0,y0,x1,y1,
    input wire [2:0] orientation,
    input wire [7:0] error_score,margin,
    input wire [15:0] cells,
    input wire [4:0] components,
    input wire [1:0] candidates,
    input wire [10:0] ax,ay,bx,by,cx,cy,
    input wire [7:0] reason,
    output reg [15:0] data,
    output reg sync
);
    localparam integer LAST=FEATURE_PACKET?31:15;
    wire [15:0] input_words[0:30];
    assign input_words[0]=16'ha53c;
    assign input_words[1]={(FEATURE_PACKET?4'h2:4'h1),kind,result_valid,config_id[14],source_valid,cal_done,busy,(kind==3&&components==31),candidates};
    assign input_words[2]=result_frame[15:0];assign input_words[3]=result_frame[31:16];
    assign input_words[4]={1'b0,config_id};
    assign input_words[5]={5'd0,x0};assign input_words[6]={5'd0,y0};
    assign input_words[7]={5'd0,x1};assign input_words[8]={5'd0,y1};
    assign input_words[9]={13'd0,orientation};assign input_words[10]=cells;
    assign input_words[11]={11'd0,components};assign input_words[12]={margin,error_score};
    assign input_words[13]=source_frame[15:0];assign input_words[14]=source_frame[31:16];
    // Reserved word identifies changed HANDS score semantics without changing packet length.
    assign input_words[15]=FEATURE_PACKET&&config_id[14:12]==7?16'h0300:0;
    assign input_words[16]={5'd0,ax};assign input_words[17]={5'd0,ay};
    assign input_words[18]={5'd0,bx};assign input_words[19]={5'd0,by};
    assign input_words[20]={5'd0,cx};assign input_words[21]={5'd0,cy};
    assign input_words[22]={8'd0,reason};assign input_words[23]=16'd8;
    genvar g;generate for(g=24;g<31;g=g+1)begin: g_reserved assign input_words[g]=0;end endgenerate
    reg [15:0] saved[0:LAST];reg [(FEATURE_PACKET?5:4)-1:0] phase;
    reg [15:0] checksum;integer k,j;
    always @*begin checksum=0;for(j=0;j<LAST;j=j+1)checksum=checksum^input_words[j];end
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin phase<=0;data<=0;sync<=0;for(k=0;k<=LAST;k=k+1)saved[k]<=0;end
        else begin
            phase<=phase+1'b1;sync<=phase==0;
            if(phase==0)begin
                for(k=0;k<LAST;k=k+1)saved[k]<=input_words[k];saved[LAST]<=checksum;data<=16'ha53c;
            end else data<=saved[phase];
        end
    end
endmodule
