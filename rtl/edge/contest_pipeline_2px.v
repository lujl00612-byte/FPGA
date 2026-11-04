// V0: mode 0 = raw Sobel, 1 = median Sobel, 2 = median + local Canny.
// Shared camera Gaussian precedes this core; median/Sobel/NMS/hysteresis
// retain four windows, matching the four remaining RGB and hand windows.
// Manual threshold only; local hysteresis is one hop, not full tracing.
module contest_pipeline_2px #(
    parameter integer H_ACTIVE=1920,
    parameter integer EDGE_THRESHOLD=128
) (
    input wire i_clk, i_rst_n,
    input wire i_vs, i_hs, i_de, i_valid,
    input wire [47:0] i_rgbx2,
    input wire [11:0] i_threshold,
    input wire [1:0] i_mode,
    output reg o_vs, o_hs, o_de, o_valid,
    output reg [47:0] o_rgbx2,
    output reg [11:0] o_high_threshold,
    output reg [1:0] o_mode,
    output reg [3:0] o_classx2
);
    reg vs_d;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            vs_d<=0; o_mode<=0; o_high_threshold<=EDGE_THRESHOLD;
        end else begin
            vs_d<=i_vs;
            if (i_vs && !vs_d) begin
                o_mode <= (i_mode<=2) ? i_mode : 0;
                o_high_threshold <= i_threshold;
            end
        end
    end
    wire [7:0] gray0, gray1;
    rgb888_to_gray u_gray0 (.i_r(i_rgbx2[23:16]),.i_g(i_rgbx2[15:8]),.i_b(i_rgbx2[7:0]),.o_gray(gray0));
    rgb888_to_gray u_gray1 (.i_r(i_rgbx2[47:40]),.i_g(i_rgbx2[39:32]),.i_b(i_rgbx2[31:24]),.o_gray(gray1));

    wire m_vs,m_hs,m_de,m_mask0,m_mask1;
    wire [31:0] m_top,m_mid,m_bot;
    canny_window_2px #(.H_ACTIVE(H_ACTIVE),.DATA_WIDTH(8),.BORDER(4)) u_median_window (
        .i_clk(i_clk),.i_rst_n(i_rst_n),.i_vs(i_vs),.i_hs(i_hs),.i_de(i_de),
        .i_data(i_valid ? {gray1,gray0} : 16'd0),
        .o_vs(m_vs),.o_hs(m_hs),.o_de(m_de),.o_mask0(m_mask0),.o_mask1(m_mask1),
        .o_pair(),.o_top(m_top),.o_mid(m_mid),.o_bot(m_bot));
    wire [7:0] median0,median1;
    median9 u_med0 (.i_pixels({m_bot[23:0],m_mid[23:0],m_top[23:0]}),.o_median(median0));
    median9 u_med1 (.i_pixels({m_bot[31:8],m_mid[31:8],m_top[31:8]}),.o_median(median1));
    reg med_vs,med_hs,med_de;
    reg [15:0] med_data;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin med_vs<=0;med_hs<=0;med_de<=0;med_data<=0;end
        else begin
            med_vs<=m_vs;med_hs<=m_hs;med_de<=m_de;
            med_data[7:0]<=m_mask0 ? (o_mode==0 ? m_mid[15:8] : median0) : 8'd0;
            med_data[15:8]<=m_mask1 ? (o_mode==0 ? m_mid[23:16] : median1) : 8'd0;
        end
    end
    // Gaussian now runs on all three camera channels before this core.
    // Reuse its window instead of allocating a second full-frame line buffer.
    wire blur_vs=med_vs,blur_hs=med_hs,blur_de=med_de;
    wire [15:0] blur_data=med_data;
    wire s_vs,s_hs,s_de,s_mask0,s_mask1;
    wire [31:0] s_top,s_mid,s_bot;
    canny_window_2px #(.H_ACTIVE(H_ACTIVE),.DATA_WIDTH(8),.BORDER(5)) u_sobel_window (
        .i_clk(i_clk),.i_rst_n(i_rst_n),.i_vs(blur_vs),.i_hs(blur_hs),.i_de(blur_de),.i_data(blur_data),
        .o_vs(s_vs),.o_hs(s_hs),.o_de(s_de),.o_mask0(s_mask0),.o_mask1(s_mask1),
        .o_pair(),.o_top(s_top),.o_mid(s_mid),.o_bot(s_bot));
    wire signed [11:0] gx0,gy0,gx1,gy1;
    wire [11:0] mag0,mag1;
    sobel_3x3 u_sobel0 (
        .i_p00(s_top[7:0]),.i_p01(s_top[15:8]),.i_p02(s_top[23:16]),
        .i_p10(s_mid[7:0]),.i_p11(s_mid[15:8]),.i_p12(s_mid[23:16]),
        .i_p20(s_bot[7:0]),.i_p21(s_bot[15:8]),.i_p22(s_bot[23:16]),
        .o_gx(gx0),.o_gy(gy0),.o_magnitude(mag0));
    sobel_3x3 u_sobel1 (
        .i_p00(s_top[15:8]),.i_p01(s_top[23:16]),.i_p02(s_top[31:24]),
        .i_p10(s_mid[15:8]),.i_p11(s_mid[23:16]),.i_p12(s_mid[31:24]),
        .i_p20(s_bot[15:8]),.i_p21(s_bot[23:16]),.i_p22(s_bot[31:24]),
        .o_gx(gx1),.o_gy(gy1),.o_magnitude(mag1));
    function [1:0] direction;
        input [11:0] gx,gy;
        reg [11:0] ax,ay;
        reg [20:0] ex,y128,x53,x309;
        begin
            ax=gx[11] ? (~gx+1'b1) : gx;ay=gy[11] ? (~gy+1'b1) : gy;
            ex={9'd0,ax};y128={2'd0,ay,7'd0};
            x53=(ex<<5)+(ex<<4)+(ex<<2)+ex;x309=(ex<<8)+x53;
            if(y128<=x53) direction=0;
            else if(y128>=x309) direction=2;
            else direction=(gx[11]^gy[11]) ? 3 : 1;
        end
    endfunction
    // Per pixel: direction[1:0], L1 magnitude[11:0]. Gray comes from aligned RGB.
    reg grad_vs,grad_hs,grad_de;
    reg [27:0] grad_data;
    always @(posedge i_clk or negedge i_rst_n) begin
        if(!i_rst_n) begin grad_vs<=0;grad_hs<=0;grad_de<=0;grad_data<=0;end
        else begin
            grad_vs<=s_vs;grad_hs<=s_hs;grad_de<=s_de;
            grad_data[13:0]<=s_mask0 ? {direction(gx0,gy0),mag0} : 14'd0;
            grad_data[27:14]<=s_mask1 ? {direction(gx1,gy1),mag1} : 14'd0;
        end
    end
    wire n_vs,n_hs,n_de,n_mask0,n_mask1;
    wire [55:0] n_top,n_mid,n_bot;
    canny_window_2px #(.H_ACTIVE(H_ACTIVE),.DATA_WIDTH(14),.BORDER(6)) u_nms_window (
        .i_clk(i_clk),.i_rst_n(i_rst_n),.i_vs(grad_vs),.i_hs(grad_hs),.i_de(grad_de),.i_data(grad_data),
        .o_vs(n_vs),.o_hs(n_hs),.o_de(n_de),.o_mask0(n_mask0),.o_mask1(n_mask1),
        .o_pair(),.o_top(n_top),.o_mid(n_mid),.o_bot(n_bot));
    function [11:0] suppress;
        input [41:0] t,m,b;
        reg [11:0] a,c,value;
        begin
            value=m[25:14];
            case(m[27:26])
                0:begin a=m[11:0];c=m[39:28];end
                1:begin a=t[11:0];c=b[39:28];end
                2:begin a=t[25:14];c=b[25:14];end
                default:begin a=t[39:28];c=b[11:0];end
            endcase
            suppress=((value>a)&&(value>=c)) ? value : 12'd0;
        end
    endfunction
    wire [11:0] nms0=n_mask0 ? suppress(n_top[41:0],n_mid[41:0],n_bot[41:0]) : 12'd0;
    wire [11:0] nms1=n_mask1 ? suppress(n_top[55:14],n_mid[55:14],n_bot[55:14]) : 12'd0;
    function [1:0] classify;
        input [11:0] value;
        begin
            if(value!=0 && value>=o_high_threshold) classify=2;
            else if(value!=0 && value>=(o_high_threshold>>1)) classify=1;
            else classify=0;
        end
    endfunction
    // Per pixel: Sobel bit, class[1:0]; no duplicate luminance line memories.
    reg class_vs,class_hs,class_de;
    reg [5:0] class_data;
    always @(posedge i_clk or negedge i_rst_n) begin
        if(!i_rst_n) begin class_vs<=0;class_hs<=0;class_de<=0;class_data<=0;end
        else begin
            class_vs<=n_vs;class_hs<=n_hs;class_de<=n_de;
            class_data[2:0]<={(n_mask0 && n_mid[25:14]>=o_high_threshold),classify(nms0)};
            class_data[5:3]<={(n_mask1 && n_mid[39:28]>=o_high_threshold),classify(nms1)};
        end
    end
    wire h_vs,h_hs,h_de,h_mask0,h_mask1;
    wire [11:0] h_top,h_mid,h_bot;
    canny_window_2px #(.H_ACTIVE(H_ACTIVE),.DATA_WIDTH(3),.BORDER(7)) u_hysteresis_window (
        .i_clk(i_clk),.i_rst_n(i_rst_n),.i_vs(class_vs),.i_hs(class_hs),.i_de(class_de),.i_data(class_data),
        .o_vs(h_vs),.o_hs(h_hs),.o_de(h_de),.o_mask0(h_mask0),.o_mask1(h_mask1),
        .o_pair(),.o_top(h_top),.o_mid(h_mid),.o_bot(h_bot));
    function connected;
        input [8:0] t,m,b;
        begin
            connected=m[4] || (m[3] && (t[1]|t[4]|t[7]|m[1]|m[7]|b[1]|b[4]|b[7]));
        end
    endfunction
    wire e0=h_mask0 && ((o_mode==2) ? connected(h_top[8:0],h_mid[8:0],h_bot[8:0]) : h_mid[5]);
    wire e1=h_mask1 && ((o_mode==2) ? connected(h_top[11:3],h_mid[11:3],h_bot[11:3]) : h_mid[8]);
    always @(posedge i_clk or negedge i_rst_n) begin
        if(!i_rst_n) begin o_vs<=0;o_hs<=0;o_de<=0;o_valid<=0;o_rgbx2<=0;o_classx2<=0;end
        else begin
            o_vs<=h_vs;o_hs<=h_hs;o_de<=h_de;o_valid<=h_de;
            o_rgbx2<=h_de ? {{24{e1}},{24{e0}}} : 48'd0;
            o_classx2<=h_de ? {h_mask1 ? h_mid[7:6] : 2'd0,h_mask0 ? h_mid[4:3] : 2'd0} : 4'd0;
        end
    end
endmodule
