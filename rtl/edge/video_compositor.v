// VIEW 0: gray/edge split, 1: RGB + red edges, 2: RGB.
// CONTEST_SPLIT selects full-frame white edges/ROI policy, not a forced view.
// Recognition boxes require matching source-frame and algorithm identities.
module video_compositor #(
    parameter integer WIDTH=1920,
    parameter integer HEIGHT=1080,
    parameter integer ROI_ENABLE=0,
    parameter integer ROI_X0=WIDTH/4,ROI_Y0=HEIGHT/4,
    parameter integer ROI_X1=WIDTH/4+WIDTH/2-1,ROI_Y1=HEIGHT/4+HEIGHT/2-1,
    parameter integer LIVE_HOLD_ENABLE=0,MAX_RESULT_AGE_FRAMES=60,
    parameter integer CONFIG_BITS=14,CLASS_BITS=2,
    parameter integer CONTEST_SPLIT=0,HAND_FULL_HEIGHT=0
) (
    input wire clk,rst_n,in_vs,in_hs,in_de,
    input wire [23:0] in_rgb,
    input wire [7:0] in_gray,
    input wire in_edge,
    input wire [1:0] in_edge_alpha,
    input wire [1:0] requested_view,
    input wire source_valid,
    input wire is_frozen,
    input wire [31:0] source_id,
    input wire [CONFIG_BITS-1:0] config_id,
    input wire result_valid,
    input wire [CLASS_BITS-1:0] result_class,
    input wire [31:0] result_frame,
    input wire [CONFIG_BITS-1:0] result_config,
    input wire [10:0] box_x0,box_y0,box_x1,box_y1,
    output wire out_vs,out_hs,out_de,
    output wire [23:0] out_rgb,
    output reg [10:0] out_x,out_y,
    output reg [1:0] active_view,
    output reg [CLASS_BITS-1:0] shape_class,
    output reg shape_ready,
    output reg [7:0] shape_age,
    output reg [31:0] displayed_frame
);
    localparam integer LINE_AW=$clog2(WIDTH);
    wire [8:0] split_pixel;
    reg bank,de_d,vs_d;
    reg [10:0] x,y;
    wire first=in_de&&!de_d;
    // HANDS uses the right half for its native half-width ROI at 1:1.
    wire [10:0] read_addr=x<WIDTH/2 ? (x<<1) :
        hand_layout ? x-WIDTH/2+ROI_X0 : ((x-WIDTH/2)<<1);
    reg right_q;
    reg [23:0] direct_q;
    reg vs_q,hs_q,de_q;
    reg [10:0] bx0,by0,bx1,by1;
    reg recognition_layout,hand_layout;
    wire [10:0] roi_y0=hand_layout ? 0 : ROI_Y0;
    wire [10:0] roi_y1=hand_layout ? HEIGHT-1 : ROI_Y1;
    wire contest_layout=CONTEST_SPLIT&&!recognition_layout;
    wire [31:0] result_age=source_id-result_frame;
    wire matching_frame=source_id==result_frame||
        (LIVE_HOLD_ENABLE&&!is_frozen&&result_age<=MAX_RESULT_AGE_FRAMES);
    wire pixel_in_roi=!ROI_ENABLE||contest_layout||(x>=ROI_X0&&x<=ROI_X1&&y>=roi_y0&&y<=roi_y1);
    // Current-frame outline is independent of slow recognition boxes/results.
    wire [1:0] overlay_alpha=hand_layout?in_edge_alpha:in_edge?2'd3:2'd0;
    function [23:0] red_blend;
        input [23:0] rgb;
        input [1:0] alpha;
        reg [9:0] r,g,b;
        begin
            r={2'd0,rgb[23:16]};g={2'd0,rgb[15:8]};b={2'd0,rgb[7:0]};
            case(alpha)
                1:begin r=r*3+257;g=g*3+2;b=b*3+2;red_blend={r[9:2],g[9:2],b[9:2]};end
                2:begin r=r+256;g=g+1;b=b+1;red_blend={r[8:1],g[8:1],b[8:1]};end
                3:red_blend=24'hff0000;
                default:red_blend=rgb;
            endcase
        end
    endfunction
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            bank<=0;de_d<=0;vs_d<=0;x<=0;y<=0;out_x<=0;out_y<=0;
            active_view<=CONTEST_SPLIT ? 0 : 1;shape_class<=0;shape_ready<=0;shape_age<=0;displayed_frame<=0;
            right_q<=0;direct_q<=0;
            vs_q<=0;hs_q<=0;de_q<=0;bx0<=0;by0<=0;bx1<=0;by1<=0;
            recognition_layout<=0;hand_layout<=0;
        end else begin
            de_d<=in_de;vs_d<=in_vs;
            if(in_vs&&!vs_d) begin
                y<=0;
                recognition_layout<=config_id[CONFIG_BITS-1];
                hand_layout<=HAND_FULL_HEIGHT&&(config_id>>12)==7;
                active_view<=requested_view<=2 ? requested_view : (CONTEST_SPLIT ? 0 : 1);
            end
            else if(de_d&&!in_de) begin y<=y+1'b1;bank<=~bank;end
            x<=in_de ? x+1'b1 : 11'd0;
            if(first&&y==0) begin
                displayed_frame<=source_id;
                shape_ready<=source_valid&&result_valid&&matching_frame&&config_id==result_config;
                shape_age<=result_age>255 ? 8'hff : result_age[7:0];
                shape_class<=result_class;
                bx0<=ROI_ENABLE&&box_x0<ROI_X0 ? ROI_X0 : box_x0;
                by0<=ROI_ENABLE&&box_y0<roi_y0 ? roi_y0 : box_y0;
                bx1<=ROI_ENABLE&&box_x1>ROI_X1 ? ROI_X1 : box_x1;
                by1<=ROI_ENABLE&&box_y1>roi_y1 ? roi_y1 : box_y1;
            end
            out_x<=x;out_y<=y;
            right_q<=x>=WIDTH/2;
            direct_q<=active_view==1&&pixel_in_roi?red_blend(in_rgb,overlay_alpha):in_rgb;
            vs_q<=in_vs;hs_q<=in_hs;de_q<=in_de;
        end
    end
    true_dual_port_ram #(.DATA_WIDTH(9),.ADDR_WIDTH(LINE_AW+1),.RAM_INIT_FILE("")) split_lines(
        .clka(clk),.clkb(clk),.we1(in_de),.we2(1'b0),
        .addr1({bank,x[LINE_AW-1:0]}),.addr2({~bank,read_addr[LINE_AW-1:0]}),
        .din1({in_edge,in_gray}),.din2(9'd0),.dout1(),.dout2(split_pixel));
    wire [7:0] split_gray=split_pixel[7:0];
    wire split_edge=split_pixel[8];
    wire [10:0] split_native_x=hand_layout ? out_x-WIDTH/2+ROI_X0 : (out_x-WIDTH/2)<<1;
    wire split_in_roi=!ROI_ENABLE||contest_layout||(split_native_x>=ROI_X0&&split_native_x<=ROI_X1&&
        out_y>0&&out_y-1>=roi_y0&&out_y-1<=roi_y1);
    wire [23:0] edge_color=contest_layout||hand_layout ? 24'hffffff : 24'hff0000;
    wire [23:0] base=active_view==0 ? (out_y==0 ? 24'd0 : (right_q ? (split_edge&&split_in_roi ? edge_color : 24'd0) : {3{split_gray}})) : direct_q;
    wire [10:0] draw_x0=active_view==0 ? (hand_layout ? WIDTH/2+bx0-ROI_X0 : WIDTH/2+(bx0>>1)) : bx0;
    wire [10:0] draw_x1=active_view==0 ? (hand_layout ? WIDTH/2+bx1-ROI_X0 : WIDTH/2+(bx1>>1)) : bx1;
    wire [11:0] draw_y0={1'b0,by0}+(active_view==0);
    wire [11:0] draw_y1={1'b0,by1}+(active_view==0);
    wire in_box=(out_x>=draw_x0)&&(out_x<=draw_x1)&&(out_y>=draw_y0)&&(out_y<=draw_y1);
    wire border=in_box&&((out_x==draw_x0)||(out_x==draw_x1)||(out_y==draw_y0)||(out_y==draw_y1));
    wire show_box=shape_ready&&(shape_class==1||shape_class==2||shape_class==4||(shape_class>=5&&shape_class<=14))&&(active_view!=2)&&border;
    wire [10:0] guide_x0=active_view==0 ? (hand_layout ? WIDTH/2 : WIDTH/2+(ROI_X0>>1)) : ROI_X0;
    wire [10:0] guide_x1=active_view==0 ? (hand_layout ? WIDTH-1 : WIDTH/2+(ROI_X1>>1)) : ROI_X1;
    wire [11:0] guide_y0=hand_layout&&active_view==0 ? 0 : roi_y0+(active_view==0);
    wire [11:0] guide_y1=hand_layout ? HEIGHT-1 : roi_y1+(active_view==0);
    wire guide_inside=out_x>=guide_x0&&out_x<=guide_x1&&out_y>=guide_y0&&out_y<=guide_y1;
    wire guide_border=guide_inside&&(out_x<=guide_x0+1||out_x+1>=guide_x1||out_y<=guide_y0+1||out_y+1>=guide_y1);
    wire show_guide=ROI_ENABLE&&!contest_layout&&active_view!=2&&guide_border;
    assign out_rgb=!de_q ? 24'd0 : show_guide ? 24'hffff00 : show_box ? (shape_class==1 ? 24'h00a0ff : shape_class==2 ? 24'h00ff40 : shape_class==4 ? 24'hff8000 : 24'hff00ff) : base;
    assign out_vs=vs_q;assign out_hs=hs_q;assign out_de=de_q;
endmodule
