// Centred RGB line delays; the pyramid uses two, and each consumer uses four.
module rgb_align_2px #(parameter integer H_ACTIVE=1920,WINDOWS=4,FIRST_BORDER=4) (
    input wire i_clk,i_rst_n,i_vs,i_hs,i_de,i_valid,
    input wire [47:0] i_rgbx2,
    output wire [47:0] o_rgbx2,
    output wire o_vs,o_hs,o_de,o_valid
);
    wire [WINDOWS:0] vs,hs,de;
    wire [47:0] data[0:WINDOWS];
    assign vs[0]=i_vs;assign hs[0]=i_hs;assign de[0]=i_de;
    assign data[0]=i_valid ? i_rgbx2 : 48'd0;
    genvar n;
    generate for(n=0;n<WINDOWS;n=n+1) begin : stage
        wire wvs,whs,wde,m0,m1;
        wire [95:0] mid;
        reg rvs,rhs,rde;
        reg [47:0] rgb;
        canny_window_2px #(.H_ACTIVE(H_ACTIVE),.DATA_WIDTH(24),.BORDER(n+FIRST_BORDER)) window (
            .i_clk(i_clk),.i_rst_n(i_rst_n),.i_vs(vs[n]),.i_hs(hs[n]),.i_de(de[n]),.i_data(data[n]),
            .o_vs(wvs),.o_hs(whs),.o_de(wde),.o_mask0(m0),.o_mask1(m1),.o_pair(),.o_top(),.o_mid(mid),.o_bot());
        always @(posedge i_clk or negedge i_rst_n) begin
            if(!i_rst_n) begin rvs<=0;rhs<=0;rde<=0;rgb<=0;end
            else begin
                rvs<=wvs;rhs<=whs;rde<=wde;
                rgb<={m1 ? mid[71:48] : 24'd0,m0 ? mid[47:24] : 24'd0};
            end
        end
        assign vs[n+1]=rvs;assign hs[n+1]=rhs;assign de[n+1]=rde;assign data[n+1]=rgb;
    end endgenerate
    assign o_rgbx2=data[WINDOWS];
    assign o_vs=vs[WINDOWS];assign o_hs=hs[WINDOWS];assign o_de=de[WINDOWS];assign o_valid=de[WINDOWS];
endmodule
