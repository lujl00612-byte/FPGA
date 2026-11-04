// Selected8px component silhouette + same-frame16px in-hand gray, midpoint contrast x2.
module hand_cnn_match #(parameter integer MAP_W=120,MAP_H=135)(
    input wire clk,rst_n,start,
    input wire [7:0] x0,y0,x1,y1,
    output reg [$clog2(MAP_W*MAP_H)-1:0] mask_address,
    input wire mask_q,
    output reg [11:0] gray_address,
    input wire [8:0] gray_q,
    output wire done,accepted,
    output wire [3:0] digit,
    output wire [7:0] distance,runner_up,
    output wire [3:0] raw_class
);
    localparam integer COARSE_W=(MAP_W+1)/2;
    localparam IDLE=0,CROP_REQ=1,CROP_WAIT=2,CROP_STORE=3,GRAY_STORE=4,SET_MID=5,
        NORM_REQ=6,NORM_WAIT=7,NORM_STORE=8,START_CORE=9,WAIT_CORE=10;
    reg [3:0] state;
    reg [9:0] pixel;
    reg [8:0] span,center_x2,center_y2;
    reg crop_pad,load_we,core_start;
    reg [10:0] load_addr,probe_addr;
    reg [7:0] load_data,saved_gray,gray_min,gray_max,midpoint;
    wire [7:0] probe_data;
    wire [14:0] xproduct={pixel[4:0],1'b1}*span;
    wire [14:0] yproduct={pixel[9:5],1'b1}*span;
    wire signed [10:0] sx2=$signed({2'd0,center_x2})-$signed({2'd0,span})+$signed({1'b0,xproduct[14:5]});
    wire signed [10:0] sy2=$signed({2'd0,center_y2})-$signed({2'd0,span})+$signed({1'b0,yproduct[14:5]});
    wire signed [10:0] sx=sx2>>>1,sy=sy2>>>1;
    wire outside=sx<0||sy<0||sx>=MAP_W||sy>=MAP_H;
    wire sample_valid=!crop_pad&&mask_q&&gray_q[8]&&gray_q[7:0]!=0;
    wire signed [10:0] contrast=($signed({3'd0,probe_data})-$signed({3'd0,midpoint}))<<<1;
    wire [7:0] normalized=probe_data==0?8'd0:contrast>127?8'h7f:contrast< -128?8'h80:contrast[7:0];
    wire [8:0] box_w={1'b0,x1}-{1'b0,x0}+1'b1,box_h={1'b0,y1}-{1'b0,y0}+1'b1;
    hand_cnn_core core(.clk(clk),.rst_n(rst_n),.start(core_start),.load_we(load_we),.load_addr(load_addr),.load_data(load_data),
        .probe_addr(probe_addr),.probe_data(probe_data),.busy(),.done(done),.accepted(accepted),.digit(digit),.distance(distance),.runner_up(runner_up),.raw_class(raw_class));
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            state<=IDLE;pixel<=0;span<=0;center_x2<=0;center_y2<=0;crop_pad<=0;
            mask_address<=0;gray_address<=0;load_we<=0;core_start<=0;load_addr<=0;load_data<=0;probe_addr<=0;
            saved_gray<=0;gray_min<=255;gray_max<=0;midpoint<=128;
        end else begin
            load_we<=0;core_start<=0;
            case(state)
                IDLE:if(start)begin
                    span<=(box_w>box_h?box_w:box_h)+4;
                    center_x2<={1'b0,x0}+{1'b0,x1}+1'b1;center_y2<={1'b0,y0}+{1'b0,y1}+1'b1;
                    gray_min<=255;gray_max<=0;pixel<=0;state<=CROP_REQ;
                end
                CROP_REQ:begin
                    mask_address<=outside?0:sy*MAP_W+sx;
                    gray_address<=outside?0:(sy>>>1)*COARSE_W+(sx>>>1);
                    crop_pad<=outside;state<=CROP_WAIT;
                end
                CROP_WAIT:state<=CROP_STORE;
                CROP_STORE:begin
                    load_we<=1;load_addr<={1'b0,pixel};load_data<=crop_pad||!mask_q?8'h80:8'h7f;
                    saved_gray<=sample_valid?gray_q[7:0]:0;
                    if(sample_valid)begin
                        if(gray_q[7:0]<gray_min)gray_min<=gray_q[7:0];
                        if(gray_q[7:0]>gray_max)gray_max<=gray_q[7:0];
                    end
                    state<=GRAY_STORE;
                end
                GRAY_STORE:begin
                    load_we<=1;load_addr<={1'b1,pixel};load_data<=saved_gray;
                    if(pixel==1023)begin pixel<=0;state<=SET_MID;end
                    else begin pixel<=pixel+1'b1;state<=CROP_REQ;end
                end
                SET_MID:begin midpoint<=gray_max>=gray_min?({1'b0,gray_min}+{1'b0,gray_max})>>1:128;state<=NORM_REQ;end
                NORM_REQ:begin probe_addr<={1'b1,pixel};state<=NORM_WAIT;end
                NORM_WAIT:state<=NORM_STORE;
                NORM_STORE:begin
                    load_we<=1;load_addr<={1'b1,pixel};load_data<=normalized;
                    if(pixel==1023)state<=START_CORE;
                    else begin pixel<=pixel+1'b1;state<=NORM_REQ;end
                end
                START_CORE:begin core_start<=1;state<=WAIT_CORE;end
                WAIT_CORE:if(done)state<=IDLE;
                default:state<=IDLE;
            endcase
        end
    end
endmodule
