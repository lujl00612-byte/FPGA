// Fixed binary cleanup and native-pixel hand outline. No adaptive thresholds.
// Four windows after pyramid fusion match rgb_align_2px exactly.
module hand_contour_2px #(parameter integer H_ACTIVE=1920) (
    input wire clk,rst_n,in_vs,in_hs,in_de,in_valid,
    input wire [47:0] rgbx2,
    output wire [1:0] skin,contour,
    output wire [3:0] contour_alpha
);
    wire [1:0] raw_skin,weak_skin;
    reg [11:0] pair_x;
    reg vs_prev;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin pair_x<=0;vs_prev<=0;end
        else begin
            vs_prev<=in_vs;
            if(in_vs&&!vs_prev)pair_x<=0;
            else pair_x<=in_de?pair_x+1'b1:12'd0;
        end
    end
    wire in_hand_roi=pair_x>=H_ACTIVE/8&&pair_x<3*H_ACTIVE/8;
    hand_skin_2px gate(.rgbx2(rgbx2),.skin(raw_skin),.weak_skin(weak_skin));
    wire [4:0] vs,hs,de;
    wire [3:0] data[0:4];
    assign vs[0]=in_vs;assign hs[0]=in_hs;assign de[0]=in_de;
    // bit0=foreground, bit1=strong-center confidence until the final outline stage.
    assign data[0]=in_valid&&in_hand_roi?{raw_skin[1],weak_skin[1],raw_skin[0],weak_skin[0]}:4'd0;
    function [3:0] votes;
        input [7:0] t,m,b;input integer offset;
        begin
            votes={3'd0,t[offset]}+{3'd0,t[offset+2]}+{3'd0,t[offset+4]}+
                  {3'd0,m[offset]}+{3'd0,m[offset+2]}+{3'd0,m[offset+4]}+
                  {3'd0,b[offset]}+{3'd0,b[offset+2]}+{3'd0,b[offset+4]};
        end
    endfunction
    genvar n;
    generate for(n=0;n<4;n=n+1)begin: stage
        wire wvs,whs,wde,m0,m1;
        wire [7:0] top,mid,bot;
        wire [3:0] count0=votes(top,mid,bot,0),count1=votes(top,mid,bot,2);
        wire [3:0] seed_count0=votes(top,mid,bot,1),seed_count1=votes(top,mid,bot,3);
        // Strong thin runs survive with3/9 support; dense weak areas can bridge missing skin.
        // No unconditional dilation/erosion: a one-pixel open finger gap has at
        // most6 foreground neighbors and is not filled. Strong thin tips survive.
        wire keep0=mid[2]&&(count0>=3||(mid[3]&&count0>=2));
        wire keep1=mid[4]&&(count1>=3||(mid[5]&&count1>=2));
        wire next0=n==0?(mid[2]&&((mid[3]&&count0>=3)||seed_count0>=2||count0>=7)):
            n==1?(keep0||(!mid[2]&&count0>=7)):n==2?(keep0||(!mid[2]&&count0>=8)):mid[2];
        wire next1=n==0?(mid[4]&&((mid[5]&&count1>=3)||seed_count1>=2||count1>=7)):
            n==1?(keep1||(!mid[4]&&count1>=7)):n==2?(keep1||(!mid[4]&&count1>=8)):mid[4];
        wire edge0=n==3&&mid[2]&&!(top[2]&&mid[0]&&mid[4]&&bot[2]);
        wire edge1=n==3&&mid[4]&&!(top[4]&&mid[2]&&mid[6]&&bot[4]);
        wire [1:0] alpha0=edge0?2'd3:n==3&&!mid[2]&&count0>=2&&count0<=4?2'd1:2'd0;
        wire [1:0] alpha1=edge1?2'd3:n==3&&!mid[4]&&count1>=2&&count1<=4?2'd1:2'd0;
        reg rvs,rhs,rde;reg [3:0] result;
        reg [3:0] alpha;
        canny_window_2px #(.H_ACTIVE(H_ACTIVE),.DATA_WIDTH(2),.BORDER(n+4)) window(
            .i_clk(clk),.i_rst_n(rst_n),.i_vs(vs[n]),.i_hs(hs[n]),.i_de(de[n]),.i_data(data[n]),
            .o_vs(wvs),.o_hs(whs),.o_de(wde),.o_mask0(m0),.o_mask1(m1),.o_pair(),
            .o_top(top),.o_mid(mid),.o_bot(bot));
        always @(posedge clk or negedge rst_n)begin
            if(!rst_n)begin rvs<=0;rhs<=0;rde<=0;result<=0;alpha<=0;end
            else begin
                rvs<=wvs;rhs<=whs;rde<=wde;
                result<={m1&&(n==3?edge1:mid[5]&&next1),m1&&next1,
                          m0&&(n==3?edge0:mid[3]&&next0),m0&&next0};
                alpha<={m1?alpha1:2'd0,m0?alpha0:2'd0};
            end
        end
        assign vs[n+1]=rvs;assign hs[n+1]=rhs;assign de[n+1]=rde;assign data[n+1]=result;
    end endgenerate
    assign skin={data[4][2],data[4][0]};
    assign contour={data[4][3],data[4][1]};
    assign contour_alpha=stage[3].alpha;
endmodule
