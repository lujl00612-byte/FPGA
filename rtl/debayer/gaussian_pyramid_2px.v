// Three levels: L0 1920x1080, L1 960x540, L2 480x270.
// L1 reuses the camera's Gaussian before its contrast-preserving limit.
// Only line memories are needed; no frame store or DDR traffic is added.
module gaussian_pyramid_2px #(parameter integer WIDTH=1920,HEIGHT=1080) (
    input wire clk,rst_n,in_vs,in_hs,in_de,in_valid,
    input wire [47:0] rgbx2,
    input wire [15:0] gaussian_grayx2,
    output reg out_vs,out_hs,out_de,out_valid,
    output reg [47:0] out_rgbx2
);
    localparam integer CW=$clog2(WIDTH/4);
    reg [10:0] pair_x,raster_y;
    reg vs_d,de_d;
    wire frame_start=in_vs&&!vs_d;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin pair_x<=0;raster_y<=0;vs_d<=0;de_d<=0;end
        else begin
            vs_d<=in_vs;de_d<=in_de;
            if(frame_start)begin pair_x<=0;raster_y<=0;end
            else begin
                pair_x<=in_de?pair_x+1'b1:11'd0;
                if(de_d&&!in_de)raster_y<=raster_y+1'b1;
            end
        end
    end
    // The centred camera Gaussian represents row raster_y-1. Odd raster
    // rows therefore select even source coordinates in both dimensions.
    wire l1_valid=in_de&&in_valid&&raster_y[0];
    wire l2_valid;
    wire [7:0] l2_gray;
    wire [10:0] l2_x,l2_y;
    pyramid_reduce_gray #(.WIDTH(WIDTH/2)) reduce_l2(
        .clk(clk),.rst_n(rst_n),.valid(l1_valid),.x(pair_x),.y(raster_y>>1),
        .gray(gaussian_grayx2[7:0]),.out_valid(l2_valid),.out_x(l2_x),.out_y(l2_y),.out_gray(l2_gray));

    // Two existing-style centred line delays give L2 time to reach the
    // corresponding column before it is read for the full-resolution pixel.
    wire base_vs,base_hs,base_de,base_valid;
    wire [47:0] base_rgb;
    rgb_align_2px #(.H_ACTIVE(WIDTH),.WINDOWS(2),.FIRST_BORDER(2)) base_delay(
        .i_clk(clk),.i_rst_n(rst_n),.i_vs(in_vs),.i_hs(in_hs),.i_de(in_de),.i_valid(in_valid),
        .i_rgbx2(rgbx2),.o_rgbx2(base_rgb),.o_vs(base_vs),.o_hs(base_hs),.o_de(base_de),.o_valid(base_valid));
    reg [10:0] base_pair,base_y;
    reg base_vs_prev,base_de_prev;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin base_pair<=0;base_y<=0;base_vs_prev<=0;base_de_prev<=0;end
        else begin
            base_vs_prev<=base_vs;base_de_prev<=base_de;
            if(base_vs&&!base_vs_prev)begin base_pair<=0;base_y<=0;end
            else begin
                base_pair<=base_de?base_pair+1'b1:11'd0;
                if(base_de_prev&&!base_de)base_y<=base_y+1'b1;
            end
        end
    end
    wire [10:0] guide_y=(base_y-11'd3)>>2;
    wire [CW-1:0] guide_x=base_pair>>1;
    wire [7:0] guide_gray;
    true_dual_port_ram #(.DATA_WIDTH(8),.ADDR_WIDTH(CW+1),.RAM_INIT_FILE("")) guide_lines(
        .clka(clk),.clkb(clk),.we1(l2_valid),.we2(1'b0),
        .addr1({l2_y[0],l2_x[CW-1:0]}),.addr2({guide_y[0],guide_x}),
        .din1(l2_gray),.din2(8'd0),.dout1(),.dout2(guide_gray));
    reg [47:0] base_rgb_d;
    reg bvs,bhs,bde,bvalid,guide_ready;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin base_rgb_d<=0;bvs<=0;bhs<=0;bde<=0;bvalid<=0;guide_ready<=0;end
        else begin
            base_rgb_d<=base_rgb;bvs<=base_vs;bhs<=base_hs;bde<=base_de;bvalid<=base_valid;
            guide_ready<=base_de&&base_y>=3&&base_y<HEIGHT;
        end
    end
    wire [7:0] base_luma0,base_luma1;
    rgb888_to_gray gray0(.i_r(base_rgb_d[23:16]),.i_g(base_rgb_d[15:8]),.i_b(base_rgb_d[7:0]),.o_gray(base_luma0));
    rgb888_to_gray gray1(.i_r(base_rgb_d[47:40]),.i_g(base_rgb_d[39:32]),.i_b(base_rgb_d[31:24]),.o_gray(base_luma1));
    function [23:0] fuse;
        input [23:0] rgb;
        input [7:0] luminance,guide;
        input ready;
        reg signed [9:0] difference,correction,value;
        integer channel;
        begin
            difference=$signed({2'd0,guide})-$signed({2'd0,luminance});
            // Fixed flat-region gate, quarter-strength blend, at most +/-4.
            // No histogram, auto exposure or automatic edge threshold.
            correction=ready&&difference>=-16&&difference<=16 ?
                (difference<0 ? -((-difference+2)>>>2) : (difference+2)>>>2) : 0;
            for(channel=0;channel<3;channel=channel+1)begin
                value=$signed({2'd0,rgb[8*channel+:8]})+correction;
                fuse[8*channel+:8]=value<0?8'd0:value>255?8'd255:value[7:0];
            end
        end
    endfunction
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin out_vs<=0;out_hs<=0;out_de<=0;out_valid<=0;out_rgbx2<=0;end
        else begin
            out_vs<=bvs;out_hs<=bhs;out_de<=bde;out_valid<=bvalid;
            out_rgbx2<=bde?{fuse(base_rgb_d[47:24],base_luma1,guide_gray,guide_ready),
                fuse(base_rgb_d[23:0],base_luma0,guide_gray,guide_ready)}:48'd0;
        end
    end
endmodule

// Sparse scalar stream. Read-before-write retrieves row y-2 while the
// other port retrieves row y-1; both rows fit one banked memory instance.
module pyramid_reduce_gray #(parameter integer WIDTH=960)(
    input wire clk,rst_n,valid,
    input wire [10:0] x,y,
    input wire [7:0] gray,
    output reg out_valid,
    output reg [10:0] out_x,out_y,
    output reg [7:0] out_gray
);
    localparam integer AW=$clog2(WIDTH);
    wire [7:0] older,previous;
    true_dual_port_ram #(.DATA_WIDTH(8),.ADDR_WIDTH(AW+1),.RAM_INIT_FILE("")) lines(
        .clka(clk),.clkb(clk),.we1(valid),.we2(1'b0),
        .addr1({y[0],x[AW-1:0]}),.addr2({~y[0],x[AW-1:0]}),
        .din1(gray),.din2(8'd0),.dout1(older),.dout2(previous));
    reg valid_d;
    reg [10:0] x_d,y_d;
    reg [7:0] gray_d,t0,t1,m0,m1,b0,b1;
    wire [7:0] top=y_d==1?previous:older;
    wire [11:0] sum={4'd0,t0}+({4'd0,t1}<<1)+{4'd0,top}+
        ({4'd0,m0}<<1)+({4'd0,m1}<<2)+({4'd0,previous}<<1)+
        {4'd0,b0}+({4'd0,b1}<<1)+{4'd0,gray_d}+12'd8;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            valid_d<=0;x_d<=0;y_d<=0;gray_d<=0;t0<=0;t1<=0;m0<=0;m1<=0;b0<=0;b1<=0;
            out_valid<=0;out_x<=0;out_y<=0;out_gray<=0;
        end else begin
            valid_d<=valid;x_d<=x;y_d<=y;gray_d<=gray;
            out_valid<=valid_d&&x_d[0]&&y_d[0];
            if(valid_d)begin
                if(x_d==0)begin t0<=top;t1<=top;m0<=previous;m1<=previous;b0<=gray_d;b1<=gray_d;end
                else begin t0<=t1;t1<=top;m0<=m1;m1<=previous;b0<=b1;b1<=gray_d;end
                if(x_d[0]&&y_d[0])begin out_x<=x_d>>1;out_y<=y_d>>1;out_gray<=sum[11:4];end
            end
        end
    end
endmodule
