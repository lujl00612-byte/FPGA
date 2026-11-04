// Whole-transaction ownership. Grants are held even while AW/AR are stalled.
// Camera/display master A has priority at each free transaction boundary.
module axi_video_arbiter (
    input wire clk,rst_n,
    input wire [3:0] a_awid,
    input wire [31:0] a_awaddr,
    input wire [7:0] a_awlen,
    input wire [2:0] a_awsize,
    input wire [1:0] a_awburst,
    input wire [3:0] a_awcache,
    input wire [2:0] a_awprot,
    input wire a_awlock,
    input wire a_awvalid,
    input wire [127:0] a_wdata,
    input wire [15:0] a_wstrb,
    input wire a_wlast,
    input wire a_wvalid,
    input wire a_bready,
    input wire [3:0] a_arid,
    input wire [31:0] a_araddr,
    input wire [7:0] a_arlen,
    input wire [2:0] a_arsize,
    input wire [1:0] a_arburst,
    input wire [3:0] a_arcache,
    input wire [2:0] a_arprot,
    input wire a_arlock,
    input wire a_arvalid,
    input wire a_rready,
    output wire a_awready,
    output wire a_wready,
    output wire [3:0] a_bid,
    output wire [1:0] a_bresp,
    output wire a_bvalid,
    output wire a_arready,
    output wire [3:0] a_rid,
    output wire [127:0] a_rdata,
    output wire [1:0] a_rresp,
    output wire a_rlast,
    output wire a_rvalid,
    input wire [3:0] b_awid,
    input wire [31:0] b_awaddr,
    input wire [7:0] b_awlen,
    input wire [2:0] b_awsize,
    input wire [1:0] b_awburst,
    input wire [3:0] b_awcache,
    input wire [2:0] b_awprot,
    input wire b_awlock,
    input wire b_awvalid,
    input wire [127:0] b_wdata,
    input wire [15:0] b_wstrb,
    input wire b_wlast,
    input wire b_wvalid,
    input wire b_bready,
    input wire [3:0] b_arid,
    input wire [31:0] b_araddr,
    input wire [7:0] b_arlen,
    input wire [2:0] b_arsize,
    input wire [1:0] b_arburst,
    input wire [3:0] b_arcache,
    input wire [2:0] b_arprot,
    input wire b_arlock,
    input wire b_arvalid,
    input wire b_rready,
    output wire b_awready,
    output wire b_wready,
    output wire [3:0] b_bid,
    output wire [1:0] b_bresp,
    output wire b_bvalid,
    output wire b_arready,
    output wire [3:0] b_rid,
    output wire [127:0] b_rdata,
    output wire [1:0] b_rresp,
    output wire b_rlast,
    output wire b_rvalid,
    output wire [3:0] m_awid,
    output wire [31:0] m_awaddr,
    output wire [7:0] m_awlen,
    output wire [2:0] m_awsize,
    output wire [1:0] m_awburst,
    output wire [3:0] m_awcache,
    output wire [2:0] m_awprot,
    output wire m_awlock,
    output wire m_awvalid,
    output wire [127:0] m_wdata,
    output wire [15:0] m_wstrb,
    output wire m_wlast,
    output wire m_wvalid,
    output wire m_bready,
    output wire [3:0] m_arid,
    output wire [31:0] m_araddr,
    output wire [7:0] m_arlen,
    output wire [2:0] m_arsize,
    output wire [1:0] m_arburst,
    output wire [3:0] m_arcache,
    output wire [2:0] m_arprot,
    output wire m_arlock,
    output wire m_arvalid,
    output wire m_rready,
    input wire m_awready,
    input wire m_wready,
    input wire [3:0] m_bid,
    input wire [1:0] m_bresp,
    input wire m_bvalid,
    input wire m_arready,
    input wire [3:0] m_rid,
    input wire [127:0] m_rdata,
    input wire [1:0] m_rresp,
    input wire m_rlast,
    input wire m_rvalid
);
reg [1:0] wr_owner,rd_owner; reg aw_sent,ar_sent;
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin wr_owner<=0;rd_owner<=0;aw_sent<=0;ar_sent<=0;end
 else begin
  if(wr_owner==0) begin aw_sent<=0;if(a_awvalid) wr_owner<=1;else if(b_awvalid) wr_owner<=2;end
  else begin if(m_awvalid&&m_awready) aw_sent<=1;if(m_bvalid&&m_bready) begin wr_owner<=0;aw_sent<=0;end end
  if(rd_owner==0) begin ar_sent<=0;if(a_arvalid) rd_owner<=1;else if(b_arvalid) rd_owner<=2;end
  else begin if(m_arvalid&&m_arready) ar_sent<=1;if(m_rvalid&&m_rready&&m_rlast) begin rd_owner<=0;ar_sent<=0;end end
 end
end
assign m_awid=wr_owner==1 ? a_awid : b_awid;
assign m_awaddr=wr_owner==1 ? a_awaddr : b_awaddr;
assign m_awlen=wr_owner==1 ? a_awlen : b_awlen;
assign m_awsize=wr_owner==1 ? a_awsize : b_awsize;
assign m_awburst=wr_owner==1 ? a_awburst : b_awburst;
assign m_awcache=wr_owner==1 ? a_awcache : b_awcache;
assign m_awprot=wr_owner==1 ? a_awprot : b_awprot;
assign m_awlock=wr_owner==1 ? a_awlock : b_awlock;
assign m_awvalid=(wr_owner==1 ? a_awvalid : wr_owner==2 ? b_awvalid : 1'b0)&&!aw_sent;
assign m_wdata=wr_owner==1 ? a_wdata : b_wdata;
assign m_wstrb=wr_owner==1 ? a_wstrb : b_wstrb;
assign m_wlast=wr_owner==1 ? a_wlast : b_wlast;
assign m_wvalid=(wr_owner==1 ? a_wvalid : wr_owner==2 ? b_wvalid : 1'b0)&&aw_sent;
assign m_bready=(wr_owner==1 ? a_bready : wr_owner==2 ? b_bready : 1'b0)&&aw_sent;
assign m_arid=rd_owner==1 ? a_arid : b_arid;
assign m_araddr=rd_owner==1 ? a_araddr : b_araddr;
assign m_arlen=rd_owner==1 ? a_arlen : b_arlen;
assign m_arsize=rd_owner==1 ? a_arsize : b_arsize;
assign m_arburst=rd_owner==1 ? a_arburst : b_arburst;
assign m_arcache=rd_owner==1 ? a_arcache : b_arcache;
assign m_arprot=rd_owner==1 ? a_arprot : b_arprot;
assign m_arlock=rd_owner==1 ? a_arlock : b_arlock;
assign m_arvalid=(rd_owner==1 ? a_arvalid : rd_owner==2 ? b_arvalid : 1'b0)&&!ar_sent;
assign m_rready=(rd_owner==1 ? a_rready : rd_owner==2 ? b_rready : 1'b0)&&ar_sent;
assign a_awready=m_awready&&wr_owner==1&&!aw_sent;
assign b_awready=m_awready&&wr_owner==2&&!aw_sent;
assign a_wready=m_wready&&wr_owner==1&&aw_sent;
assign b_wready=m_wready&&wr_owner==2&&aw_sent;
assign a_bid=m_bid;
assign b_bid=m_bid;
assign a_bresp=m_bresp;
assign b_bresp=m_bresp;
assign a_bvalid=m_bvalid&&wr_owner==1&&aw_sent;
assign b_bvalid=m_bvalid&&wr_owner==2&&aw_sent;
assign a_arready=m_arready&&rd_owner==1&&!ar_sent;
assign b_arready=m_arready&&rd_owner==2&&!ar_sent;
assign a_rid=m_rid;
assign b_rid=m_rid;
assign a_rdata=m_rdata;
assign b_rdata=m_rdata;
assign a_rresp=m_rresp;
assign b_rresp=m_rresp;
assign a_rlast=m_rlast;
assign b_rlast=m_rlast;
assign a_rvalid=m_rvalid&&rd_owner==1&&ar_sent;
assign b_rvalid=m_rvalid&&rd_owner==2&&ar_sent;
endmodule
