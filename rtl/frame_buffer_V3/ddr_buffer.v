

`timescale 1ps/1ps
module ddr_buffer #(
parameter AXI_DATA_WIDTH = 512, //!AXI接口位宽
parameter AXI_ADDR_WIDTH = 33,  //!AXI地址位宽
parameter WR_FIFO_DEPTH	= 1024, //!Write fifo depth   
parameter RD_FIFO_DEPTH = 1024, //!read fifo depth
parameter FB_NUM			= 	3,//2 buffer ,3 buffer   
parameter MAX_VID_WIDTH		=	1920 ,//video width 
parameter MAX_VID_HIGHT		=	1080 ,//wideo height
parameter START_ADDR				=	33'h000201900,
parameter BURST_LEN       = 8'd15,
parameter I_VID_WIDTH = 16,
parameter AXI_STRB_WIDTH = AXI_DATA_WIDTH/8//!总共的字节数量，= AXI_DATA_WIDTH/8

) (

input 											axi_clk,

input [9:0] history_control,
input capture_error,
input capture_done,
output wire history_ready,history_read_valid,history_busy,history_fault,
output wire [31:0] history_frame_id,
output wire [1:0] history_age,
output wire [2:0] history_count,
input [1:0] bresp,

input                       wr_clk_rst_n,
input                       axi_clk_rst_n,
input                       rd_clk_rst_n,
input 											rd_start,
input											wr_start, // pulse signal 

// input		[AXI_ADDR_WIDTH-1:0]				start_wr_addr,
// input		[AXI_ADDR_WIDTH-1:0]				start_rd_addr,
input 		[31:0] 								wr_busrt_len,
input 		[31:0] 								rd_burst_len,
output		[7:0] test_cnt ,

input                     wr_fifo_rst_p,
input											wr_fifo_wrclk,
input											wr_fifo_wren,
output											wr_fifo_wrfull,
input	 [AXI_DATA_WIDTH-1:0]					wr_fifo_wrdata, 
input											rd_fifo_rdclk,
input                       rd_fifo_rst_p,
output											rd_fifo_rdvalid,
output	 [AXI_DATA_WIDTH-1:0] 					rd_fifo_rddata,
output wire										rd_fifo_rdempty,
input	 wire									rd_fifo_rden,

output 	[5:0] 									awid,
output  [AXI_ADDR_WIDTH-1:0] 					awaddr,
output  [8-1:0] 					awlen,
output  [2:0] 									awsize,
output  [1:0] 									awburst,
output  [3:0] 									awcache,
output [2:0]                    awprot,
output  										awlock,
output  										awvalid,
output  										awcobuf,
output  										awapcmd,
output  										awallstrb,
output  										awqos,
input 											awready,

output [5:0] 									arid,
output  [AXI_ADDR_WIDTH-1:0] 					araddr,
output  [8-1:0] 					arlen,
output  [2:0] 									arsize,
output  [1:0] 									arburst,
output  										arlock,
output  										arvalid,
output  										arapcmd,
output 											arqos,
input 											arready,
output  [3:0] 									arcache,
output [2:0]                    arprot,
output  [AXI_DATA_WIDTH-1:0] 					wdata,  
output	[31:0]									test_wdata,
output	[31:0]									test_rdata,
output  [AXI_STRB_WIDTH-1:0] 					wstrb,
output  										wlast,
output  										wvalid,
input 											wready,

input [5:0] 									rid,
input [AXI_DATA_WIDTH-1:0] 						rdata,
input 											rlast,
input 											rvalid,
output  										rready,
input [1:0] 									rresp,
output[31:0]									wr_fifo_rd_data_test,
input [5:0] 									bid,
input 											bvalid,
output  										bready,

output [7:0] test_BURST_LEN
);
assign test_BURST_LEN = BURST_LEN;

//=============================================================
//reg define 
//=============================================================   


//=============================================================
//wire define 
//============================================================= 



wire write_issue,read_issue,write_complete,read_complete,write_error,read_error;
wire [24:0] history_read_beats;
reg [24:0] write_length;
(* async_reg="true" *) reg [2:0] wr_event,rd_event;
wire write_request=wr_event[1]&&!wr_event[2];
wire read_request=rd_event[1]&&!rd_event[2];
reg dma_done,camera_done,capture_failed;
// A bank becomes readable only after both DDR completion and this capture's EOF.
wire publish_done=history_busy&&(dma_done||write_complete)&&(camera_done||capture_done);
wire publish_error=capture_failed||write_error||(capture_done&&capture_error);
always @(posedge axi_clk or negedge axi_clk_rst_n) begin
    if(!axi_clk_rst_n) begin dma_done<=0;camera_done<=0;capture_failed<=0;end
    else if(write_request&&!history_busy) begin dma_done<=0;camera_done<=0;capture_failed<=0;end
    else if(history_busy) begin
        if(write_complete) dma_done<=1;
        if(capture_done) begin camera_done<=1;capture_failed<=capture_error;end
    end
end
always @(posedge axi_clk or negedge axi_clk_rst_n) begin
    if(!axi_clk_rst_n) begin wr_event<=0;rd_event<=0;write_length<=0;end
    else begin
        wr_event<={wr_event[1:0],wr_start};rd_event<={rd_event[1:0],rd_start};
        if(write_request) write_length<=wr_busrt_len;
    end
end
wire                            wr_sw_ack=1'b0;
wire		                        wr_sw 		          ;
wire		                        rd_sw			          ;
wire                            rd_sw_ack=1'b0;
wire		[AXI_ADDR_WIDTH-1:0]		wr_start_addr       ;
wire		[AXI_ADDR_WIDTH-1:0]    rd_start_addr       ; 

//=============================================================  
//RTL                                                     
//=============================================================  



ddr_wr_buffer # (
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .WR_FIFO_DEPTH(WR_FIFO_DEPTH),
    .BURST_LEN (BURST_LEN        )
  )

  u_ddr_wr_buffer (//_inst
    .axi_clk(axi_clk),
    .rst_n(axi_clk_rst_n),//(rst_n),
    .wr_start(write_issue),
    .abort_frame(capture_done&&capture_error&&history_busy),
    .start_addr(wr_start_addr),//(0),//
    .total_burst_len(write_length),
/*i*/.bank_sw_ack	(wr_sw_ack   	),
/*o*/.bank_sw 		  (wr_sw  		 	),
    .test_cnt(test_cnt),
    .wr_fifo_rst_p(wr_fifo_rst_p),
    .wr_fifo_wrclk(wr_fifo_wrclk),
    .wr_fifo_wren(wr_fifo_wren),
    .wr_fifo_wrfull(wr_fifo_wrfull),
    .wr_fifo_wrdata(wr_fifo_wrdata),
    .awid(awid),
    .awaddr(awaddr),
    .awlen(awlen),
    .awsize(awsize),
    .awburst(awburst),
    .awcache(awcache),
    .awlock(awlock),
    .awvalid(awvalid),
    .awcobuf(awcobuf),
    .awapcmd(awapcmd),
    .awallstrb(awallstrb),
    .awprot (awprot ),
    .awqos(awqos),
    .awready(awready),
    .wdata(wdata),
    .wstrb(wstrb),
    .wlast(wlast),
    .wvalid(wvalid),
    .wready(wready),
	  .bid	( bid			),
    .bvalid	( bvalid		),
    .bresp(bresp),.frame_done(write_complete),.frame_error(write_error),
    .bready	( bready		)
  );


assign test_wdata = wdata[32:0];
assign test_rdata = rdata[32:0];
//=============================================================================================
// FIFO RD_PROCESSING
//=============================================================================================
ddr_rd_buffer # (
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .RD_FIFO_DEPTH(RD_FIFO_DEPTH),
    .BURST_LEN (BURST_LEN        )
  )
  ddr_rd_buffer_inst (
    .axi_clk(axi_clk),
    .axi_clk_rst_n(axi_clk_rst_n),
    .start(read_issue),
    .start_addr(rd_start_addr),//(0),//
    .burst_len(history_read_beats),
    .rd_fifo_rdclk(rd_fifo_rdclk),
    .rd_fifo_rst_p (rd_fifo_rst_p),
    .rd_fifo_rdvalid(rd_fifo_rdvalid),
    .rd_fifo_rddata(rd_fifo_rddata),
    .rd_fifo_rdempty(rd_fifo_rdempty),
    .rd_fifo_rden(rd_fifo_rden),
/*i*/.bank_sw_ack	(rd_sw_ack   	),
/*o*/.bank_sw 		  (rd_sw  		 	),
    .arid(arid),
    .araddr(araddr),
    .arlen(arlen),
    .arsize(arsize),
    .arburst(arburst),
    .arlock(arlock),
    .arvalid(arvalid),
    .arapcmd(arapcmd),
    .arqos(arqos),
    .arready(arready),
    .arprot (arprot ),
    .arcache(arcache),
    .rid(rid),
    .rdata(rdata),
    .rlast(rlast),
    .rvalid(rvalid),
    .rready(rready),
    .rresp(rresp),.frame_done(read_complete),.frame_error(read_error),
    .wr_fifo_rd_data_test(wr_fifo_rd_data_test)
  );
//===================================================================================== 
//
//===================================================================================== 
  


ddr_history_manager #(.ADDR_WIDTH(AXI_ADDR_WIDTH),.START_ADDR(START_ADDR),.AXI_BYTES(AXI_DATA_WIDTH/8)) u_history (
    .clk(axi_clk),.rst_n(axi_clk_rst_n),
    .write_request(write_request),.write_done(publish_done),.write_error(publish_error),.write_beats(wr_busrt_len[24:0]),
    .read_request(read_request),.read_done(read_complete),.read_error(read_error|(rvalid&&rready&&rresp!=0)),
    .freeze_request(history_control[9]),.step_sequence(history_control[8:1]),.step_older(history_control[0]),
    .write_issue(write_issue),.read_issue(read_issue),.write_address(wr_start_addr),.read_address(rd_start_addr),
    .read_beats(history_read_beats),.write_busy(history_busy),.read_busy(),
    .read_valid(history_read_valid),.read_frame_id(history_frame_id),.replay_age(history_age),
    .memory_ready(history_ready),.history_count(history_count),.fault(history_fault)
);



/*----------------------------------------------------------------------------------*\
                                 The function code
\*----------------------------------------------------------------------------------*/
function integer clogb2;
input [31:0] value;
begin
value = value - 1;
for (clogb2 = 0; value > 0; clogb2 = clogb2 + 1)
value = value >> 1;
end
endfunction

endmodule
