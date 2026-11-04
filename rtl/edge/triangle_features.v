// Rotation-independent general triangle contour features. Four passes over component cells:
// farthest from bbox origin -> A, farthest from A -> B, farthest from AB -> C,
// then three finite-segment support. Distances use squared lengths; no trig/division.
module triangle_features #(parameter integer CW=7)(
    input wire clk,rst_n,start,point_valid,
    input wire [1:0] pass,
    input wire [CW-1:0] x,y,origin_x,origin_y,
    input wire [15:0] count,
    output reg [CW-1:0] ax,ay,bx,by,cx,cy,
    output wire accepted,
    output wire [7:0] error_score
);
    function [2*CW+2:0] distance_sq;
        input [CW-1:0] x0,y0,x1,y1;
        reg signed [CW:0] dx,dy;
        begin dx=$signed({1'b0,x0})-$signed({1'b0,x1});dy=$signed({1'b0,y0})-$signed({1'b0,y1});distance_sq=dx*dx+dy*dy;end
    endfunction
    function signed [2*CW+4:0] cross_product;
        input [CW-1:0] x0,y0,x1,y1,px,py;
        reg signed [CW:0] dx,dy,qx,qy;
        begin dx=$signed({1'b0,x1})-$signed({1'b0,x0});dy=$signed({1'b0,y1})-$signed({1'b0,y0});
            qx=$signed({1'b0,px})-$signed({1'b0,x0});qy=$signed({1'b0,py})-$signed({1'b0,y0});cross_product=dx*qy-dy*qx;end
    endfunction
    function [CW:0] delta;
        input [CW-1:0] a,b;begin delta=a>=b?a-b:b-a;end
    endfunction
    function near_segment;
        input [CW-1:0] x0,y0,x1,y1,px,py;
        reg signed [2*CW+4:0] value;
        reg [CW:0] lx,hx,ly,hy;
        reg [CW+2:0] tolerance;
        begin
            lx=x0<x1?x0:x1;hx=x0>x1?x0:x1;ly=y0<y1?y0:y1;hy=y0>y1?y0:y1;
            value=cross_product(x0,y0,x1,y1,px,py);tolerance=(delta(x0,x1)+delta(y0,y1))*3;
            near_segment=((value<0?-value:value)<<1)<=tolerance&&{1'b0,px}+2>=lx&&{1'b0,px}<=hx+2&&{1'b0,py}+2>=ly&&{1'b0,py}<=hy+2;
        end
    endfunction
    function [7:0] segment_bin;
        input [CW-1:0] x0,y0,x1,y1,px,py;
        reg [CW:0] span,pos,low;
        reg [2:0] index;
        integer k;
        begin
            if(delta(x0,x1)>=delta(y0,y1))begin span=delta(x0,x1);low=x0<x1?x0:x1;pos=px>=low?px-low:0;end
            else begin span=delta(y0,y1);low=y0<y1?y0:y1;pos=py>=low?py-low:0;end
            if(pos>span)pos=span;
            index=0;
            for(k=1;k<8;k=k+1)if((pos*8)>=span*k)index=k;
            segment_bin=8'b1<<index;
        end
    endfunction
    function side_covered;
        input [7:0] mask;
        reg [3:0] hit_count;
        reg [2:0] middle;
        begin
            hit_count={3'd0,mask[0]}+{3'd0,mask[1]}+{3'd0,mask[2]}+{3'd0,mask[3]}+
                 {3'd0,mask[4]}+{3'd0,mask[5]}+{3'd0,mask[6]}+{3'd0,mask[7]};
            middle={2'd0,mask[2]}+{2'd0,mask[3]}+{2'd0,mask[4]}+{2'd0,mask[5]};
            side_covered=hit_count>=6&&middle>=3;
        end
    endfunction
    wire signed [2*CW+4:0] ab_cross=cross_product(ax,ay,bx,by,x,y);
    wire [2*CW+4:0] measure=pass==0?distance_sq(x,y,origin_x,origin_y):pass==1?distance_sq(x,y,ax,ay):ab_cross<0?-ab_cross:ab_cross;
    wire n0=near_segment(ax,ay,bx,by,x,y),n1=near_segment(bx,by,cx,cy,x,y),n2=near_segment(cx,cy,ax,ay,x,y);
    reg [2*CW+4:0] maximum;
    reg [1:0] previous_pass;
    reg have_point;
    reg [15:0] support,s0,s1,s2;
    reg [7:0] coverage0,coverage1,coverage2;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin ax<=0;ay<=0;bx<=0;by<=0;cx<=0;cy<=0;maximum<=0;previous_pass<=0;have_point<=0;support<=0;s0<=0;s1<=0;s2<=0;coverage0<=0;coverage1<=0;coverage2<=0;end
        else if(start)begin ax<=0;ay<=0;bx<=0;by<=0;cx<=0;cy<=0;maximum<=0;previous_pass<=0;have_point<=0;support<=0;s0<=0;s1<=0;s2<=0;coverage0<=0;coverage1<=0;coverage2<=0;end
        else begin
            previous_pass<=pass;
            if(pass!=previous_pass)begin maximum<=0;have_point<=0;end
            if(point_valid)begin
                if(pass!=3)have_point<=1;
                if(pass!=3&&(pass!=previous_pass||!have_point||measure>maximum))begin
                    maximum<=measure;
                    case(pass)0:begin ax<=x;ay<=y;end 1:begin bx<=x;by<=y;end 2:begin cx<=x;cy<=y;end endcase
                end
                if(pass==3)begin
                    if(n0||n1||n2)support<=support+1'b1;
                    if(n0)s0<=s0+1'b1;if(n1)s1<=s1+1'b1;if(n2)s2<=s2+1'b1;
                    if(n0)coverage0<=coverage0|segment_bin(ax,ay,bx,by,x,y);
                    if(n1)coverage1<=coverage1|segment_bin(bx,by,cx,cy,x,y);
                    if(n2)coverage2<=coverage2|segment_bin(cx,cy,ax,ay,x,y);
                end
            end
        end
    end
    wire [2*CW+2:0] l0=distance_sq(ax,ay,bx,by),l1=distance_sq(bx,by,cx,cy),l2=distance_sq(cx,cy,ax,ay);
    wire [2*CW+2:0] shortest=l0<l1?(l0<l2?l0:l2):(l1<l2?l1:l2);
    wire [CW:0] span0=delta(ax,bx)>delta(ay,by)?delta(ax,bx):delta(ay,by);
    wire [CW:0] span1=delta(bx,cx)>delta(by,cy)?delta(bx,cx):delta(by,cy);
    wire [CW:0] span2=delta(cx,ax)>delta(cy,ay)?delta(cx,ax):delta(cy,ay);
    wire [CW:0] longest_span=span0>span1?(span0>span2?span0:span2):(span1>span2?span1:span2);
    wire signed [2*CW+4:0] area_signed=cross_product(ax,ay,bx,by,cx,cy);
    wire [2*CW+4:0] area2=area_signed<0?-area_signed:area_signed;
    assign accepted=count!=0&&shortest>=36&&area2>=longest_span*4&&support*100>=count*85&&
        s0*2>=span0&&s1*2>=span1&&s2*2>=span2&&side_covered(coverage0)&&side_covered(coverage1)&&side_covered(coverage2);
    assign error_score=count-support>255?255:count-support;
endmodule
