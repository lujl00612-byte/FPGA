// Shared camera preprocessing, two pixels per clock. One existing RGB alignment
// window is moved here; pyramid supplies two more shared line delays before the consumers.
module camera_smooth_2px #(parameter integer H_ACTIVE=1920) (
    input wire clk,rst_n,in_vs,in_hs,in_de,in_valid,
    input wire [47:0] rgbx2,
    output reg out_vs,out_hs,out_de,out_valid,
    output reg [47:0] smooth_rgbx2,
    output reg [15:0] pyramid_grayx2
);
    wire wvs,whs,wde,mask0,mask1;
    wire [95:0] top,mid,bot;
    canny_window_2px #(.H_ACTIVE(H_ACTIVE),.DATA_WIDTH(24),.BORDER(1)) window (
        .i_clk(clk),.i_rst_n(rst_n),.i_vs(in_vs),.i_hs(in_hs),.i_de(in_de),
        .i_data(in_valid ? rgbx2 : 48'd0),
        .o_vs(wvs),.o_hs(whs),.o_de(wde),.o_mask0(mask0),.o_mask1(mask1),
        .o_pair(),.o_top(top),.o_mid(mid),.o_bot(bot));

    // Rounded [1 2 1]'*[1 2 1]/16. Bound each channel's correction to 24/255
    // so smoothing reduces small fluctuations without washing out strong edges.
    // The limit is fixed; it does not change the manual Canny threshold.
    function [7:0] gaussian_channel;
        input [71:0] t,m,b;
        input integer channel;
        reg [11:0] sum;
        begin
            sum={4'd0,t[channel+:8]}+({4'd0,t[channel+24+:8]}<<1)+{4'd0,t[channel+48+:8]}+
                ({4'd0,m[channel+:8]}<<1)+({4'd0,m[channel+24+:8]}<<2)+({4'd0,m[channel+48+:8]}<<1)+
                {4'd0,b[channel+:8]}+({4'd0,b[channel+24+:8]}<<1)+{4'd0,b[channel+48+:8]}+12'd8;
            gaussian_channel=sum[11:4];
        end
    endfunction

    wire [47:0] gaussian_rgbx2;
    wire [7:0] gray0,gray1;
    rgb888_to_gray gray_low(.i_r(gaussian_rgbx2[23:16]),.i_g(gaussian_rgbx2[15:8]),.i_b(gaussian_rgbx2[7:0]),.o_gray(gray0));
    rgb888_to_gray gray_high(.i_r(gaussian_rgbx2[47:40]),.i_g(gaussian_rgbx2[39:32]),.i_b(gaussian_rgbx2[31:24]),.o_gray(gray1));
    function [7:0] bounded;
        input [7:0] blurred,center;
        begin
            if({1'b0,blurred}>{1'b0,center}+9'd24)bounded={1'b0,center}+9'd24;
            else if({1'b0,center}>{1'b0,blurred}+9'd24)bounded={1'b0,center}-9'd24;
            else bounded=blurred;
        end
    endfunction
    genvar lane,channel;
    generate for(lane=0;lane<2;lane=lane+1)begin: pixel
        for(channel=0;channel<3;channel=channel+1)begin: component
            assign gaussian_rgbx2[24*lane+8*channel+:8]=
                gaussian_channel(top[24*lane+:72],mid[24*lane+:72],bot[24*lane+:72],8*channel);
            always @(posedge clk or negedge rst_n)begin
                if(!rst_n) smooth_rgbx2[24*lane+8*channel+:8]<=0;
                else smooth_rgbx2[24*lane+8*channel+:8]<=(lane==0 ? mask0 : mask1) ?
                    bounded(gaussian_rgbx2[24*lane+8*channel+:8],mid[24*lane+24+8*channel+:8]) : 8'd0;
            end
        end
    end endgenerate
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin out_vs<=0;out_hs<=0;out_de<=0;out_valid<=0;pyramid_grayx2<=0;end
        else begin out_vs<=wvs;out_hs<=whs;out_de<=wde;out_valid<=wde;pyramid_grayx2<={mask1?gray1:8'd0,mask0?gray0:8'd0};end
    end
endmodule
