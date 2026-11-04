
/////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2013-2021 Efinix Inc. All rights reserved.
//
// Description:
// Example top file for ti60f225 dev kit OOB design
//
// Language:  Verilog 2001
//Ti60f225_sc431hai2hdmi_v6：
//使用了最新版本的framebuffer_v3;
// ------------------------------------------------------------------------------

/////////////////////////////////////////////////////////////////////////////////
//`define SOFT_TAP 1
`include "ddr3_controller/ddr3_parameter.vh"
// `include "define.v"

module ti60f225_oob_top #(

	parameter                       RANK_RATIO         = 1,       // # of unique CS outputs per rank
	parameter                       ASYN_AXI_CLK       = `ASYN_AXI_CLK, 
	parameter                       RANKS              = `RANKS,
	parameter                       CK_WIDTH           = `CK_WIDTH,       // # of CK/CK# outputs to memory   
	parameter                       CKE_WIDTH          = `CKE_WIDTH,       // # of cke outputs
	parameter                       CS_WIDTH           = `CS_WIDTH,       // # of unique CS outputs
	parameter                       BANK_WIDTH         = `BANK_WIDTH,       // # of bank bits
	parameter                       ROW_WIDTH          = `ROW_WIDTH,       // DRAM address bus width
	parameter                       COL_WIDTH          = `COL_WIDTH,      // column address width
	parameter                       DM_WIDTH           = `DM_WIDTH,       // # of DM (data mask)
	parameter                       DQS_WIDTH          = `DQS_WIDTH,       // # of DQS (strobe)
	parameter                       DQ_WIDTH           = `DQ_WIDTH,      // # of DQ (data)
	parameter                       ODT_WIDTH          = `ODT_WIDTH,
	parameter                       DQ_CNT_WIDTH       = `DQ_CNT_WIDTH,       // = ceil(log2(DQ_WIDTH))
	parameter                       DQS_CNT_WIDTH      = `DQS_CNT_WIDTH,       // = ceil(log2(DQS_WIDTH))  
	parameter                       DRAM_WIDTH         = `DRAM_WIDTH,       // # of DQ per DQS   
	parameter                       DATA_WIDTH         = `DATA_WIDTH,
	parameter                       ADDR_WIDTH         = `ADDR_WIDTH,    
	parameter                       AXI_ID_WIDTH       = `AXI_ID_WIDTH,
	parameter                       AXI_ADDR_WIDTH     = `AXI_ADDR_WIDTH,
	parameter                       AXI_DATA_WIDTH     = `AXI_DATA_WIDTH
)
(

  (* syn_peri_port = 0 *) input jtag_inst1_CAPTURE,
  (* syn_peri_port = 0 *) input jtag_inst1_DRCK,
  (* syn_peri_port = 0 *) input jtag_inst1_RESET,
  (* syn_peri_port = 0 *) input jtag_inst1_RUNTEST,
  (* syn_peri_port = 0 *) input jtag_inst1_SEL,
  (* syn_peri_port = 0 *) input jtag_inst1_SHIFT,
  (* syn_peri_port = 0 *) input jtag_inst1_TCK,
  (* syn_peri_port = 0 *) input jtag_inst1_TDI,
  (* syn_peri_port = 0 *) input jtag_inst1_TMS,
  (* syn_peri_port = 0 *) input jtag_inst1_UPDATE,
  (* syn_peri_port = 0 *) output jtag_inst1_TDO,

   //Clocks 
	input	wire	i_arstn,
    // Sobel / Canny 边缘检测阈值按键（低有效）
    input	wire	i_key0_n,   // KEY0 @GPIOL_07 : 阈值 +8
    input wire i_key2_n, // V4 KEY2 @GPIOR_21; old led[0] removed
    input	wire	i_key1_n,   // KEY1 @GPIOL_03 : 阈值 -8
    input	wire	i_mipi_rx_pclk,
    input wire  vid_clk_dvi2,
    input wire hdmi_tx_slow_clk,
    input wire CLK_5M,
    input  wire CLK_25M,
	output  wire    pll_inst1_RSTN,
	input	wire	i_pll_locked,
	input 	wire  	pll_locked,
	output  wire    pll_inst4_RSTN,
	input   wire    pll_inst4_LOCKED,
	output  wire  	USER_PLL_RSTN,
    output 	wire 	DDR3_PLL_RSTN,
	input 	wire  	user_pll_locked,
    //CSI Interface
    input	 wire		io_cam_sda_IN,
    output wire   io_cam_sda_OUT,
    output wire		io_cam_sda_OE,

    output io_cam_scl_OUT,
    input io_cam_scl_IN,
    output io_cam_scl_OE,

    output	wire		o_cam_rst_p,
    
    input	wire		i_cam_ck_LP_P_IN,
    input	wire		i_cam_ck_LP_N_IN,
    output	wire		o_cam_ck_HS_TERM,
    output	wire		o_cam_ck_HS_ENA,
    input	wire		i_cam_ck_CLKOUT,
    
    input	wire	[7:0]			cam_d0_HS_IN,
    input	  wire		      cam_d0_LP_P_IN,
    input	  wire		      cam_d0_LP_N_IN,
    output	wire		      cam_d0_HS_TERM,
    output	wire		      cam_d0_HS_ENA,
    output	wire		      cam_d0_RST,
    output	wire		      cam_d0_FIFO_RD,
    input	  wire		      cam_d0_FIFO_EMPTY,
    
    input 	wire	[7:0]			cam_d1_HS_IN,
    input	  wire		        cam_d1_LP_P_IN,
    input	  wire		        cam_d1_LP_N_IN,
    output	wire		        cam_d1_HS_TERM,
    output	wire		        cam_d1_HS_ENA,
    output	wire		        cam_d1_RST,
    output	wire		        cam_d1_FIFO_RD,
    input	  wire		        cam_d1_FIFO_EMPTY,
    
    input 	wire	[7:0]			cam_d2_HS_IN,
    input	  wire		        cam_d2_LP_P_IN,
    input	  wire		        cam_d2_LP_N_IN,
    output	wire		        cam_d2_HS_TERM,
    output	wire		        cam_d2_HS_ENA,
    output	wire		        cam_d2_RST,
    output	wire		        cam_d2_FIFO_RD,
    input	  wire		        cam_d2_FIFO_EMPTY,  
   
    input 	wire	[7:0]			cam_d3_HS_IN,
    input	  wire		        cam_d3_LP_P_IN,
    input	  wire		        cam_d3_LP_N_IN,
    output	wire		        cam_d3_HS_TERM,
    output	wire		        cam_d3_HS_ENA,
    output	wire		        cam_d3_RST,
    output	wire		        cam_d3_FIFO_RD,
    input	  wire		        cam_d3_FIFO_EMPTY,

	
	input 					tx_cal_clk_90edge,
  	input 					rx_cal_clk,
  	input 					tx_cal_clk,
	input                              core_clk,     // CORE CLK @ 100MHz
	input                              sdram_clk,    // SDRAM CK @ 400MHz
	// PLL status flags  
	output [2:0]                       pll_shift,  
	output [4:0]                       pll_shift_sel,
	output                             pll_shift_ena,  
	// memory interface ports
	output                             ddr_ck_hi,
	output                             ddr_ck_lo,
	output                             ddr_reset_n,
	output [CKE_WIDTH-1:0]             ddr_cke,     
	output [ROW_WIDTH-1:0]             ddr_addr,
	output [BANK_WIDTH-1:0]            ddr_ba,
	output                             ddr_cas_n,
 
	output [CS_WIDTH*RANK_RATIO-1:0]   ddr_cs_n,
	output                             ddr_ras_n,
	output                             ddr_we_n,
	
	input  [DQS_WIDTH-1:0]             ddr_dqs_in_hi,
	input  [DQS_WIDTH-1:0]             ddr_dqs_in_lo,
	input  [DQ_WIDTH-1:0]              ddr_dq_in_hi,
	input  [DQ_WIDTH-1:0]              ddr_dq_in_lo,
	
	output [DQS_WIDTH-1:0]             ddr_dqs_oe,
	output [DQS_WIDTH-1:0]             ddr_dqs_oe_n,
	output [DQ_WIDTH-1:0]              ddr_dq_oe,  
	output [DQS_WIDTH-1:0]             ddr_dqs_out_hi,
	output [DQS_WIDTH-1:0]             ddr_dqs_out_lo,
	output [DQ_WIDTH-1:0]              ddr_dq_out_hi,
	output [DQ_WIDTH-1:0]              ddr_dq_out_lo,
	output [DM_WIDTH-1:0]              ddr_dm_hi,
	output [DM_WIDTH-1:0]              ddr_dm_lo,
	output [ODT_WIDTH-1:0]             ddr_odt,

       //LED
       output [3:1] led,

       // MIPI DSI
       input	wire	                     i_mipi_tx_pclk		,
       output	wire	                     mipi_dp_clk_LP_P_OUT		,
       output	wire	                     mipi_dp_clk_LP_N_OUT		,
       output	wire	[7:0] 	              mipi_dp_clk_HS_OUT		,
       output	wire	                     mipi_dp_clk_HS_OE		,
       output	wire	                     mipi_dp_data3_LP_P_OUT	,
       output	wire	                     mipi_dp_data2_LP_P_OUT	,
       output	wire	                     mipi_dp_data1_LP_P_OUT	,
       output	wire	                     mipi_dp_data0_LP_P_OUT	,
       output	wire	                     mipi_dp_data3_LP_N_OUT	,
       output	wire	                     mipi_dp_data2_LP_N_OUT	,
       output	wire	                     mipi_dp_data1_LP_N_OUT	,
       output	wire	                     mipi_dp_data0_LP_N_OUT	,
       output	wire	[7:0] 	              mipi_dp_data0_HS_OUT	       ,
       output	wire	[7:0] 	              mipi_dp_data1_HS_OUT	       ,
       output	wire	[7:0] 	              mipi_dp_data2_HS_OUT	       ,
       output	wire	[7:0] 	              mipi_dp_data3_HS_OUT	       ,
       output	wire	                     mipi_dp_data3_HS_OE		,
       output	wire	                     mipi_dp_data2_HS_OE		,
       output	wire	                     mipi_dp_data1_HS_OE		,
       output	wire	                     mipi_dp_data0_HS_OE		,

       output	wire	                     mipi_dp_clk_RST		,
       output	wire	                     mipi_dp_data0_RST		,
       output	wire	                     mipi_dp_data1_RST		,
       output	wire	                     mipi_dp_data2_RST		,
       output	wire	                     mipi_dp_data3_RST		,
       output	wire	                     mipi_dp_clk_LP_P_OE		,
       output	wire	                     mipi_dp_clk_LP_N_OE		,
       output	wire	                     mipi_dp_data3_LP_P_OE	,
       output	wire	                     mipi_dp_data3_LP_N_OE	,
       output	wire	                     mipi_dp_data2_LP_P_OE	,
       output	wire	                     mipi_dp_data2_LP_N_OE	,
       output	wire	                     mipi_dp_data1_LP_P_OE	,
       output	wire	                     mipi_dp_data1_LP_N_OE	,
       output	wire	                     mipi_dp_data0_LP_P_OE	,
       output	wire	                     mipi_dp_data0_LP_N_OE	,

       input  wire	                     mipi_dp_data0_LP_P_IN	,
       input  wire	                     mipi_dp_data0_LP_N_IN	,
       output	wire	                     LCD_RST_P			,
       output wire                        LCD_POWER			,

       // hdmi interface

    output tmds_tx_clk_TX_OE,
    output [9:0] tmds_tx_clk_TX_DATA,
    output tmds_tx_clk_TX_RST,
    output tmds_tx_data0_TX_OE,
    output [9:0] tmds_tx_data0_TX_DATA,
    output tmds_tx_data0_TX_RST,
    output tmds_tx_data1_TX_OE,
    output [9:0] tmds_tx_data1_TX_DATA,
    output tmds_tx_data1_TX_RST,
    output tmds_tx_data2_TX_OE,
    output [9:0] tmds_tx_data2_TX_DATA,
    output tmds_tx_data2_TX_RST


);

function integer log2;
	input	integer	val;
	integer	i;
	begin
		log2 = 0;
		for (i=0; 2**i<val; i=i+1)
			log2 = i+1;
	end
endfunction


//===============================================================================
//localparam
//===============================================================================
localparam WR_FIFO_DEPTH  = 1024;
localparam RD_FIFO_DEPTH  = 1024;

// localparam	MAX_HRES		= 12'd1920;
// localparam	MAX_VRES		= 12'd1080;
// localparam	HSP			= 8'd2;
// localparam	HBP			= 8'd88;
// localparam	HFP			= 8'd120;
// localparam	VSP			= 8'd2;
// localparam	VBP			= 8'd20;
// localparam	VFP			= 8'd20;

localparam MAX_HRES = 1920;
localparam HFP      = 88;
localparam HSP      = 44;
localparam HBP      = 148;

localparam MAX_VRES = 1080;
localparam VFP      = 4;
localparam VSP      = 5;
localparam VBP      = 36;

//================ Sobel / Canny 边缘检测参数 ================
localparam [11:0] EDGE_THRESHOLD      = 12'd128;
localparam [11:0] EDGE_THRESHOLD_STEP = 12'd8;     // 用户指定步进8
localparam [11:0] EDGE_THRESHOLD_MIN  = 12'd32;    // 下限 32，避免降到 0 导致整屏全白
localparam [11:0] EDGE_THRESHOLD_MAX  = 12'd192;   // 用户指定上限192
// display_mode=1 → edge_pipeline 输出「全帧二值边缘」，供分屏合成器使用
// （=0 时输出左半原图/右半边缘，合成器无法同时拿到全帧原图与全帧边缘）
localparam        EDGE_DISPLAY_MODE   = 1'b1;
//===============================================================================
//signal
//===============================================================================
   
wire                              app_sr_active;
wire                              app_ref_ack;
wire                              app_zq_ack;
wire                              cal_done;

// Slave Interface Write Address Ports
wire [AXI_ID_WIDTH-1:0]           s_axi_awid;
wire [AXI_ADDR_WIDTH-1:0]         s_axi_awaddr;
wire [7:0]                        s_axi_awlen;
wire [2:0]                        s_axi_awsize;
wire [1:0]                        s_axi_awburst;
wire [0:0]                        s_axi_awlock;
wire [3:0]                        s_axi_awcache;
wire [2:0]                        s_axi_awprot;
wire                              s_axi_awvalid;
wire                              s_axi_awready;
// Slave Interface Write Data Ports
wire [AXI_DATA_WIDTH-1:0]         s_axi_wdata;
wire [(AXI_DATA_WIDTH/8)-1:0]     s_axi_wstrb;
wire                              s_axi_wlast;
wire                              s_axi_wvalid;
wire                              s_axi_wready;
// Slave Interface Write Response Ports
wire                              s_axi_bready;
wire [AXI_ID_WIDTH-1:0]           s_axi_bid;
wire [1:0]                        s_axi_bresp;
wire                              s_axi_bvalid;
// Slave Interface Read Address Ports
wire [AXI_ID_WIDTH-1:0]           s_axi_arid;
wire [AXI_ADDR_WIDTH-1:0]         s_axi_araddr;
wire [7:0]                        s_axi_arlen;
wire [2:0]                        s_axi_arsize;
wire [1:0]                        s_axi_arburst;
wire [0:0]                        s_axi_arlock;
wire [3:0]                        s_axi_arcache;
wire [2:0]                        s_axi_arprot;
wire                              s_axi_arvalid;
wire                              s_axi_arready;
// Slave Interface Read Data Ports
wire                              s_axi_rready;
wire [AXI_ID_WIDTH-1:0]           s_axi_rid;
wire [AXI_DATA_WIDTH-1:0]         s_axi_rdata;
wire [1:0]                        s_axi_rresp;
wire                              s_axi_rlast;
wire                              s_axi_rvalid;




////////////////////////////////////////////////////////////////
// System & Debugger
wire    w_arstn;
// wire	w_sysclk_mcu_arstn;
// wire	w_sysclk_mcu_arst;
wire	w_mipi_rx_pclk_arstn;
wire	w_mipi_rx_pclk_arst;

wire		       w_mipi_rx_vs;
wire		       w_mipi_rx_hs;
wire	       w_mipi_rx_de;
wire	[63:0]			w_mipi_rx_data	;

wire					io_systemReset;



//===================================================================================================
//reset module
//===================================================================================================

assign w_arstn  		       = i_pll_locked & pll_locked & user_pll_locked;
assign pll_inst1_RSTN  		= i_arstn;
assign USER_PLL_RSTN      		= i_arstn;
assign mipi_dsi_tx_pll_RSTN 	= i_arstn;
assign DDR3_PLL_RSTN 		= i_arstn;
reset_ctrl
#(
	.NUM_RST		(2),
	.CYCLE			(1),
	.IN_RST_ACTIVE	(4'b00),
	.OUT_RST_ACTIVE	(4'b10)
)
inst_reset_ctrl
(
	.i_arst		({2{w_arstn}}),//({{4{i_pll_locked}},                  {2{i_arstn}}}),
	.i_clk			({2{i_mipi_rx_pclk}}),
	.o_srst		({w_mipi_rx_pclk_arst, w_mipi_rx_pclk_arstn})
);



reg [25:0] cnt = 'd0;
always @( posedge core_clk)
begin 
       cnt <= cnt + 1'b1;
end
assign led[3:1] = 3'b000;                    // 阈值档位光柱已取消（用户反馈观感不佳）

//========================================================================================================
//MIPI RX
//========================================================================================================
wire i_mipi_clk ;
assign i_mipi_clk = core_clk;

		assign	cam_d0_RST		= 1'b0;
		assign	cam_d1_RST		= 1'b0;
		assign  cam_d2_RST = 1'b0;
    assign  cam_d3_RST = 1'b0;
	
wire [15:0] mipi_debug_out;
		

		csi_rx_controller inst_efx_csi2_rx
		(
              .reset_n			(i_arstn),
              .clk				(i_mipi_clk),
              .reset_byte_HS_n	(i_arstn),
              .clk_byte_HS		  (i_cam_ck_CLKOUT),
              .reset_pixel_n		(w_mipi_rx_pclk_arstn),
              .clk_pixel			  (i_mipi_rx_pclk),
              
              .Rx_LP_CLK_P		  (i_cam_ck_LP_P_IN),
              .Rx_LP_CLK_N		  (i_cam_ck_LP_N_IN),
              .Rx_HS_enable_C		(o_cam_ck_HS_ENA),
              .LVDS_termen_C		(o_cam_ck_HS_TERM),
              
              .Rx_LP_D_P			({cam_d3_LP_P_IN, cam_d2_LP_P_IN, cam_d1_LP_P_IN, cam_d0_LP_P_IN}),//(r_mipi_rx_data_LP_P_IN_2P),
              .Rx_LP_D_N			({cam_d3_LP_N_IN, cam_d2_LP_N_IN, cam_d1_LP_N_IN, cam_d0_LP_N_IN}),//(r_mipi_rx_data_LP_N_IN_2P),
              .Rx_HS_D_0			(cam_d0_HS_IN),//(r_mipi_rx_data_HS_IN_2P[0*8+:8]),
              .Rx_HS_D_1			(cam_d1_HS_IN),//(r_mipi_rx_data_HS_IN_2P[1*8+:8]),
              .Rx_HS_D_2			(cam_d2_HS_IN),
              .Rx_HS_D_3			(cam_d3_HS_IN),
              .Rx_HS_D_4			(),
              .Rx_HS_D_5			(),
              .Rx_HS_D_6			(),
              .Rx_HS_D_7			(),
              .Rx_HS_enable_D		({cam_d3_HS_ENA    ,cam_d2_HS_ENA    ,cam_d1_HS_ENA    ,cam_d0_HS_ENA    }),//( w_cam_d_HS_ENA),
              .LVDS_termen_D		({cam_d3_HS_TERM   ,cam_d2_HS_TERM   ,cam_d1_HS_TERM   ,cam_d0_HS_TERM   }),
              .fifo_rd_enable		({cam_d3_FIFO_RD   ,cam_d2_FIFO_RD   ,cam_d1_FIFO_RD   ,cam_d0_FIFO_RD   }),
              .fifo_rd_empty		({cam_d3_FIFO_EMPTY,cam_d2_FIFO_EMPTY,cam_d1_FIFO_EMPTY,cam_d0_FIFO_EMPTY}),
              .DLY_enable_D		       (),
              .DLY_inc_D			(),
              .u_dly_enable_D		(),
              .u_dly_inc_D		       (),
              
              .axi_clk			(1'b0),
              .axi_reset_n		       (1'b0),
              .axi_awaddr			(6'b0),
              .axi_awvalid		       (1'b0),
              .axi_awready		       (),
              .axi_wdata			(32'b0),
              .axi_wvalid			(1'b0),
              .axi_wready			(),
              
              .axi_bvalid			(),
              .axi_bready			(1'b0),
              .axi_araddr			(6'b0),
              .axi_arvalid		       (1'b0),
              .axi_arready		       (),
              .axi_rdata			(),
              .axi_rvalid			(),
              .axi_rready			(1'b1),
              
              .hsync_vc0			(w_mipi_rx_hs),
              .hsync_vc1			(),
              .hsync_vc2			(),
              .hsync_vc3			(),
              .vsync_vc0			(w_mipi_rx_vs),
              .vsync_vc1			(),
              .vsync_vc2			(),
              .vsync_vc3			(),
              .vc				(),
              .word_count			(),
              .shortpkt_data_field        (),
              .datatype			(),
              .pixel_per_clk		(),
              .pixel_data			(w_mipi_rx_data),
              .pixel_data_valid	       (w_mipi_rx_de),
              .irq				(),
              .mipi_debug_out(mipi_debug_out)
		);

//     wire		       w1_mipi_rx_vs;
// wire		       w1_mipi_rx_hs;
// wire	       w1_mipi_rx_de;
// wire	[39:0]			w1_mipi_rx_data	;
// sensor_clipper  sensor_clipper_inst (
//     .clk(i_mipi_rx_pclk),
//     .i_vs(w_mipi_rx_vs),
//     .i_hs(w_mipi_rx_hs),
//     .i_de(w_mipi_rx_de),
//     .i_dat(w_mipi_rx_data[39:0]),

//     .o_hs(w1_mipi_rx_hs),
//     .o_vs(w1_mipi_rx_vs),
//     .o_de(w1_mipi_rx_de),
//     .o_dat(w1_mipi_rx_data)
   
//   );


wire mdebug_pixel_fifo_full     = mipi_debug_out[0] ;
wire mdebug_pixel_fifo_empty    = mipi_debug_out[1] ;
wire mdebug_crc_error           = mipi_debug_out[2] ;
wire mdebug_ecc_1bit_error      = mipi_debug_out[3] ;
wire mdebug_ecc_2bit_error      = mipi_debug_out[4] ;
wire mdebug_undersize_pkt_error = mipi_debug_out[5] ;
wire mdebug_line_vc0_error      = mipi_debug_out[6] ;
wire mdebug_frame_vc0_error    = mipi_debug_out[10];   
wire mdebug_receive_error      = mipi_debug_out[14];


//========================================================================================================
//
//========================================================================================================
		

//*************** imx219 config********************/
// mipi_config_imx219_top u_config_imx219(
// 										.i_sys_clk(CLK_5M)    	,    /////48M 
// 										.sys_rstn(vid_rst_n )    ,
// 										.o_sen_rst_n(o_cam_rstn)  	,
										
										// .o_iic_sda_OE(io_cam_sda_OE) ,
										// .i_iic_sda(io_cam_sda_IN)   	,
										// .o_iic_sda(io_cam_sda_OUT)   	,
										// .o_iic_scl(io_cam_scl)    	
										// ); 	

wire scl_padoen_o;
wire sda_padoen_o;


reg [12:0] i2c_rst_cnt = '0;

always @( posedge CLK_5M or negedge w_arstn )
begin
    if( !w_arstn )
       i2c_rst_cnt <= 'd0;
    else 
       i2c_rst_cnt <= i2c_rst_cnt[12] ? i2c_rst_cnt : i2c_rst_cnt + 1'b1;
end
wire i2c_rst_n = i2c_rst_cnt[12];

i2c_master_ctrl_top u2_i2c_master_ctrl_top(
  /*i*/.clk			(CLK_5M		),
  /*i*/.rst_n			(i2c_rst_n		),
  /*i*/.scl_pad_i     (io_cam_scl_IN),//(1'b1),
  /*o*/.scl_pad_o     (io_cam_scl_OUT),
  /*o*/.scl_padoen_o  (scl_padoen_o),
  /*i*/.sda_pad_i     (io_cam_sda_IN),
  /*o*/.sda_pad_o     (io_cam_sda_OUT),
  /*o*/.sda_padoen_o  (sda_padoen_o)
  
  );
assign o_cam_rst_p = ~w_arstn;
assign io_cam_scl_OE = ~scl_padoen_o;
assign io_cam_sda_OE = ~sda_padoen_o;

//=====================================================================================
//frame buffer
//=====================================================================================
wire [7:0] 	ch0_r;
wire [7:0]    ch0_g;
wire [7:0]    ch0_b;
wire ch0_vs;
wire ch0_hs;
wire ch0_de;
wire [3:0] fb_axi_awid;
wire [31:0] fb_axi_awaddr;
wire [7:0] fb_axi_awlen;
wire [2:0] fb_axi_awsize;
wire [1:0] fb_axi_awburst;
wire [2:0] fb_axi_awprot;
wire [3:0] fb_axi_awcache;
wire fb_axi_awlock;
wire fb_axi_awvalid;
wire fb_axi_awready;
wire [3:0] fb_axi_arid;
wire [31:0] fb_axi_araddr;
wire [7:0] fb_axi_arlen;
wire [2:0] fb_axi_arsize;
wire [1:0] fb_axi_arburst;
wire [2:0] fb_axi_arprot;
wire [3:0] fb_axi_arcache;
wire fb_axi_arlock;
wire fb_axi_arvalid;
wire fb_axi_arready;
wire [127:0] fb_axi_wdata;
wire [15:0] fb_axi_wstrb;
wire fb_axi_wlast;
wire fb_axi_wvalid;
wire fb_axi_wready;
wire [3:0] fb_axi_bid;
wire fb_axi_bvalid;
wire [1:0] fb_axi_bresp;
wire fb_axi_bready;
wire [3:0] fb_axi_rid;
wire [127:0] fb_axi_rdata;
wire fb_axi_rlast;
wire fb_axi_rvalid;
wire fb_axi_rready;
wire [1:0] fb_axi_rresp;
wire [3:0] exact_axi_awid;
wire [31:0] exact_axi_awaddr;
wire [7:0] exact_axi_awlen;
wire [2:0] exact_axi_awsize;
wire [1:0] exact_axi_awburst;
wire [2:0] exact_axi_awprot;
wire [3:0] exact_axi_awcache;
wire exact_axi_awlock;
wire exact_axi_awvalid;
wire exact_axi_awready;
wire [3:0] exact_axi_arid;
wire [31:0] exact_axi_araddr;
wire [7:0] exact_axi_arlen;
wire [2:0] exact_axi_arsize;
wire [1:0] exact_axi_arburst;
wire [2:0] exact_axi_arprot;
wire [3:0] exact_axi_arcache;
wire exact_axi_arlock;
wire exact_axi_arvalid;
wire exact_axi_arready;
wire [127:0] exact_axi_wdata;
wire [15:0] exact_axi_wstrb;
wire exact_axi_wlast;
wire exact_axi_wvalid;
wire exact_axi_wready;
wire [3:0] exact_axi_bid;
wire exact_axi_bvalid;
wire [1:0] exact_axi_bresp;
wire exact_axi_bready;
wire [3:0] exact_axi_rid;
wire [127:0] exact_axi_rdata;
wire exact_axi_rlast;
wire exact_axi_rvalid;
wire exact_axi_rready;
wire [1:0] exact_axi_rresp;
assign exact_axi_awid=4'd0;
assign exact_axi_arid=4'd0;
assign exact_axi_awburst=2'd1;
assign exact_axi_arburst=2'd1;
assign exact_axi_awprot=3'd2;
assign exact_axi_arprot=3'd2;
assign exact_axi_awcache=4'd3;
assign exact_axi_arcache=4'd3;
assign exact_axi_awlock=1'b0;
assign exact_axi_arlock=1'b0;
axi_video_arbiter ddr_owner (
.clk(core_clk),.rst_n(vid_rst_n),
.a_awid(fb_axi_awid),
.a_awaddr(fb_axi_awaddr),
.a_awlen(fb_axi_awlen),
.a_awsize(fb_axi_awsize),
.a_awburst(fb_axi_awburst),
.a_awprot(fb_axi_awprot),
.a_awcache(fb_axi_awcache),
.a_awlock(fb_axi_awlock),
.a_awvalid(fb_axi_awvalid),
.a_awready(fb_axi_awready),
.a_arid(fb_axi_arid),
.a_araddr(fb_axi_araddr),
.a_arlen(fb_axi_arlen),
.a_arsize(fb_axi_arsize),
.a_arburst(fb_axi_arburst),
.a_arprot(fb_axi_arprot),
.a_arcache(fb_axi_arcache),
.a_arlock(fb_axi_arlock),
.a_arvalid(fb_axi_arvalid),
.a_arready(fb_axi_arready),
.a_wdata(fb_axi_wdata),
.a_wstrb(fb_axi_wstrb),
.a_wlast(fb_axi_wlast),
.a_wvalid(fb_axi_wvalid),
.a_wready(fb_axi_wready),
.a_bid(fb_axi_bid),
.a_bvalid(fb_axi_bvalid),
.a_bresp(fb_axi_bresp),
.a_bready(fb_axi_bready),
.a_rid(fb_axi_rid),
.a_rdata(fb_axi_rdata),
.a_rlast(fb_axi_rlast),
.a_rvalid(fb_axi_rvalid),
.a_rready(fb_axi_rready),
.a_rresp(fb_axi_rresp),
.b_awid(exact_axi_awid),
.b_awaddr(exact_axi_awaddr),
.b_awlen(exact_axi_awlen),
.b_awsize(exact_axi_awsize),
.b_awburst(exact_axi_awburst),
.b_awprot(exact_axi_awprot),
.b_awcache(exact_axi_awcache),
.b_awlock(exact_axi_awlock),
.b_awvalid(exact_axi_awvalid),
.b_awready(exact_axi_awready),
.b_arid(exact_axi_arid),
.b_araddr(exact_axi_araddr),
.b_arlen(exact_axi_arlen),
.b_arsize(exact_axi_arsize),
.b_arburst(exact_axi_arburst),
.b_arprot(exact_axi_arprot),
.b_arcache(exact_axi_arcache),
.b_arlock(exact_axi_arlock),
.b_arvalid(exact_axi_arvalid),
.b_arready(exact_axi_arready),
.b_wdata(exact_axi_wdata),
.b_wstrb(exact_axi_wstrb),
.b_wlast(exact_axi_wlast),
.b_wvalid(exact_axi_wvalid),
.b_wready(exact_axi_wready),
.b_bid(exact_axi_bid),
.b_bvalid(exact_axi_bvalid),
.b_bresp(exact_axi_bresp),
.b_bready(exact_axi_bready),
.b_rid(exact_axi_rid),
.b_rdata(exact_axi_rdata),
.b_rlast(exact_axi_rlast),
.b_rvalid(exact_axi_rvalid),
.b_rready(exact_axi_rready),
.b_rresp(exact_axi_rresp),
.m_awid(s_axi_awid),
.m_awaddr(s_axi_awaddr),
.m_awlen(s_axi_awlen),
.m_awsize(s_axi_awsize),
.m_awburst(s_axi_awburst),
.m_awprot(s_axi_awprot),
.m_awcache(s_axi_awcache),
.m_awlock(s_axi_awlock),
.m_awvalid(s_axi_awvalid),
.m_awready(s_axi_awready),
.m_arid(s_axi_arid),
.m_araddr(s_axi_araddr),
.m_arlen(s_axi_arlen),
.m_arsize(s_axi_arsize),
.m_arburst(s_axi_arburst),
.m_arprot(s_axi_arprot),
.m_arcache(s_axi_arcache),
.m_arlock(s_axi_arlock),
.m_arvalid(s_axi_arvalid),
.m_arready(s_axi_arready),
.m_wdata(s_axi_wdata),
.m_wstrb(s_axi_wstrb),
.m_wlast(s_axi_wlast),
.m_wvalid(s_axi_wvalid),
.m_wready(s_axi_wready),
.m_bid(s_axi_bid),
.m_bvalid(s_axi_bvalid),
.m_bresp(s_axi_bresp),
.m_bready(s_axi_bready),
.m_rid(s_axi_rid),
.m_rdata(s_axi_rdata),
.m_rlast(s_axi_rlast),
.m_rvalid(s_axi_rvalid),
.m_rready(s_axi_rready),
.m_rresp(s_axi_rresp)
);
wire freeze_request,step_older;
wire [7:0] step_sequence;
wire [1:0] view_request;
wire [9:0] history_control_axi;
wire history_ready,history_read_valid,history_busy,history_fault;
wire [31:0] history_frame_id;
wire [1:0] history_age;
wire [2:0] history_count;
config_cdc #(.WIDTH(10),.RESET_VALUE(10'd1)) history_control_cdc (
  .i_src_clk(vid_clk_dvi2),.i_src_rst_n(vid_rst_n),.i_data({freeze_request,step_sequence,step_older}),
  .i_dst_clk(core_clk),.i_dst_rst_n(vid_rst_n),.o_data(history_control_axi),.o_ready()
);
wire [40:0] history_video;
wire history_video_ready;
config_cdc #(.WIDTH(41)) history_metadata_cdc (
  .i_src_clk(core_clk),.i_src_rst_n(vid_rst_n),
  .i_data({history_ready,history_busy,history_read_valid,history_fault,history_age,history_count,history_frame_id}),
  .i_dst_clk(vid_clk_dvi2),.i_dst_rst_n(vid_rst_n),.o_data(history_video),.o_ready(history_video_ready)
);
// DDR read selection settles during vertical blanking; hold its identity through active video.
reg source_valid,ch0_de_d;
reg [31:0] source_frame_id;
reg [5:0] source_history;
always @(posedge vid_clk_dvi2 or negedge vid_rst_n) begin
  if(!vid_rst_n) begin source_valid<=0;source_frame_id<=0;source_history<=0;ch0_de_d<=0;end
  else begin
    ch0_de_d<=ch0_de;
    if(ch0_de&&!ch0_de_d&&source_first_line) begin
      source_valid<=history_video_ready&&history_video[40]&&history_video[38]&&!history_video[37];
      source_frame_id<=history_video[31:0];source_history<={history_video[36:32],history_video[37]};
    end
  end
end
reg source_first_line,ch0_vs_d;
always @(posedge vid_clk_dvi2 or negedge vid_rst_n) begin
  if(!vid_rst_n) begin source_first_line<=1;ch0_vs_d<=0;end
  else begin
    ch0_vs_d<=ch0_vs;
    if(ch0_vs&&!ch0_vs_d) source_first_line<=1;
    else if(ch0_de) source_first_line<=0;
  end
end
// RAW10 P1 is [9:0]. Read P1/P2 then P3/P4, low byte first in each pair.
  frame_buffer #(
.I_VID_WIDTH         (32),
.O_VID_WIDTH         (16),
.EXPECTED_FRAME_WORDS(MAX_HRES*MAX_VRES/4),
.START_ADDR          (32'h00000        ),
.AXI_DATA_WIDTH      ( AXI_DATA_WIDTH	),
.AXI_ADDR_WIDTH      ( AXI_ADDR_WIDTH	),
.WR_FIFO_DEPTH	      ( 1024		),    
.RD_FIFO_DEPTH 	      ( 1024 	),
.BURST_LEN  	       (127),
.FB_NUM	            (3),
.MAX_VID_WIDTH	    (960) ,
.MAX_VID_HIGHT	    (1080) 


)checker0(
       .history_control(history_control_axi),.bresp(fb_axi_bresp),
       .history_ready(history_ready),.history_read_valid(history_read_valid),.history_busy(history_busy),.history_fault(history_fault),
       .history_frame_id(history_frame_id),.history_age(history_age),.history_count(history_count),
       .axi_clk		(core_clk 	        ),
       .rst_n			(vid_rst_n   ),

/*i*/.i_clk			(i_mipi_rx_pclk      ),
/*i*/.i_vs			(w_mipi_rx_vs	),
/*i*/.i_de			(w_mipi_rx_de & w_mipi_rx_hs	),
/*i*/.vin 			({w_mipi_rx_data[19:12],w_mipi_rx_data[9:2],w_mipi_rx_data[39:32],w_mipi_rx_data[29:22]}	),
                     
/*i*/.o_clk			(vid_clk_dvi2),//(i_mipi_rx_pclk	),
/*i*/.o_hs    		(ch0_hs		),			
/*i*/.o_vs    		(ch0_vs		),			
/*i*/.o_de    		(ch0_de		),			
/*i*/.vout    		({ch0_g,ch0_b}	),//ch0_r,

/*i*/.H_FRONT_PORCH (HFP/2  		),//
/*i*/.H_SYNC 	 	    (HSP/2	 	),///2
/*i*/.H_VALID 	 	  (MAX_HRES/2     ),//		
/*i*/.H_BACK_PORCH	(HBP/2		),//		
/*i*/.V_FRONT_PORCH (VFP  		),//		
/*i*/.V_SYNC 	 	    (VSP 	 	),//		
/*i*/.V_VALID 	 	  (MAX_VRES     ),//		
/*i*/.V_BACK_PORCH	(VBP		),//		

       .awid			(fb_axi_awid	),      
       .awaddr		(fb_axi_awaddr	),
       .awlen			(fb_axi_awlen	),
       .awsize		(fb_axi_awsize	),
       .awburst		(fb_axi_awburst),
       .awprot    (fb_axi_awprot ),
       .awcache   (fb_axi_awcache),
       .awlock		(fb_axi_awlock	),
       .awvalid		(fb_axi_awvalid),
       .awready		(fb_axi_awready),

       .arid			(fb_axi_arid	  ),
       .araddr		(fb_axi_araddr	),
       .arlen			(fb_axi_arlen	),
       .arsize		(fb_axi_arsize	),
       .arburst 	(fb_axi_arburst),

       .arprot    (fb_axi_arprot ),
       .arcache   (fb_axi_arcache),
       .arlock 		(fb_axi_arlock	),
       .arvalid		(fb_axi_arvalid),
       .arready		(fb_axi_arready),

       .wdata			(fb_axi_wdata	),
       .wstrb			(fb_axi_wstrb	),
       .wlast			(fb_axi_wlast	),
       .wvalid		(fb_axi_wvalid	),
       .wready		(fb_axi_wready	),


       .rid			  (fb_axi_rid	),
       .rdata			(fb_axi_rdata	),
       .rlast			(fb_axi_rlast	),
       .rvalid 		(fb_axi_rvalid	),
       .rready		(fb_axi_rready	),
       .rresp			(fb_axi_rresp	),

       .bid			  (fb_axi_bid	),
       .bvalid		(fb_axi_bvalid	),
       .bready	  (fb_axi_bready	)
);


ddr3_top                 u_ddr3_top
(

.axi_clk                (core_clk            ),
.core_clk               (core_clk            ),
.sdram_clk              (sdram_clk           ),  
.rx_cal_clk             (rx_cal_clk          ),
.tx_cal_clk             (tx_cal_clk          ),
.tx_cal_clk_90edge      (tx_cal_clk_90edge   ),
.rstn                   (w_arstn             ),      
.pll_shift              (pll_shift           ),
.pll_shift_sel          (pll_shift_sel       ),
.pll_shift_ena          (pll_shift_ena       ),       
///////////////DDR BUS
.ddr_ck_hi              (ddr_ck_hi           ),
.ddr_ck_lo              (ddr_ck_lo           ),
.ddr_cke                (ddr_cke             ),    
.ddr_reset_n            (ddr_reset_n         ),
.ddr_cs_n               (ddr_cs_n            ),
.ddr_ras_n              (ddr_ras_n           ),
.ddr_cas_n              (ddr_cas_n           ),
.ddr_we_n               (ddr_we_n            ),     
.ddr_addr               (ddr_addr            ),
.ddr_ba                 (ddr_ba              ),

.ddr_dqs_oe             (ddr_dqs_oe          ),
.ddr_dqs_oe_n           (ddr_dqs_oe_n        ),
.ddr_dq_oe              (ddr_dq_oe           ),
.ddr_dqs_in_hi          (ddr_dqs_in_hi       ),
.ddr_dqs_in_lo          (ddr_dqs_in_lo       ),
.ddr_dq_in_hi           (ddr_dq_in_hi        ),
.ddr_dq_in_lo           (ddr_dq_in_lo        ),

.ddr_dqs_out_hi         (ddr_dqs_out_hi      ),
.ddr_dqs_out_lo         (ddr_dqs_out_lo      ),
.ddr_dq_out_hi          (ddr_dq_out_hi       ),
.ddr_dq_out_lo          (ddr_dq_out_lo       ),

.ddr_dm_hi              (ddr_dm_hi           ),
.ddr_dm_lo              (ddr_dm_lo           ),
.ddr_odt                (ddr_odt             ),

// Application interface ports
.app_sr_req                     (1'b0),
.app_ref_req                    (1'b0),
.app_zq_req                     (1'b0),
.app_sr_active                  (app_sr_active),
.app_ref_ack                    (app_ref_ack),
.app_zq_ack                     (app_zq_ack),

// Slave Interface Write Address Ports
.s_axi_awid                     (s_axi_awid        ),
.s_axi_awaddr                   (s_axi_awaddr      ),
.s_axi_awlen                    (s_axi_awlen       ),
.s_axi_awsize                   (s_axi_awsize      ),
.s_axi_awburst                  (s_axi_awburst     ),
.s_axi_awlock                   (s_axi_awlock      ),
.s_axi_awcache                  (s_axi_awcache     ),
.s_axi_awprot                   (s_axi_awprot      ),
.s_axi_awqos                    (4'h0              ),
.s_axi_awvalid                  (s_axi_awvalid     ),
.s_axi_awready                  (s_axi_awready     ),
// Slave Interface Write Data Ports
.s_axi_wdata                    (s_axi_wdata       ),
.s_axi_wstrb                    (s_axi_wstrb       ),
.s_axi_wlast                    (s_axi_wlast       ),
.s_axi_wvalid                   (s_axi_wvalid      ),
.s_axi_wready                   (s_axi_wready      ),
// Slave Interface Write Response Ports
.s_axi_bid                      (s_axi_bid         ),
.s_axi_bresp                    (s_axi_bresp       ),
.s_axi_bvalid                   (s_axi_bvalid      ),
.s_axi_bready                   (s_axi_bready      ),
// Slave Interface Read Address Ports
.s_axi_arid                     (s_axi_arid        ),
.s_axi_araddr                   (s_axi_araddr      ),
.s_axi_arlen                    (s_axi_arlen       ),
.s_axi_arsize                   (s_axi_arsize      ),
.s_axi_arburst                  (s_axi_arburst     ),
.s_axi_arlock                   (s_axi_arlock      ),
.s_axi_arcache                  (s_axi_arcache     ),
.s_axi_arprot                   (s_axi_arprot      ),
.s_axi_arqos                    (4'h0              ),
.s_axi_arvalid                  (s_axi_arvalid     ),
.s_axi_arready                  (s_axi_arready     ),
// Slave Interface Read Data Ports
.s_axi_rid                      (s_axi_rid         ),
.s_axi_rdata                    (s_axi_rdata       ),
.s_axi_rresp                    (s_axi_rresp       ),
.s_axi_rlast                    (s_axi_rlast       ),
.s_axi_rvalid                   (s_axi_rvalid      ),
.s_axi_rready                   (s_axi_rready      ),
//DEBUG       
.wrlvl_dq_check                 (wrlvl_dq_check    ) ,
.rd_level_dqs_check             (rd_level_dqs_check) ,
.init_cur_state                 (init_cur_state    ) ,
.idelay_ld                      (idelay_ld         ) ,
.mpr_rdlvl_dly                  (mpr_rdlvl_dly     ) ,
.cal_done                       (cal_done          ) 
);

//***************************************************************************
// debayer
//***************************************************************************


wire        rgb_vs;
wire        rgb_hs;
wire        rgb_de;
wire        rgb_valid;
wire [47:0] rgb_datax2;
wire [15:0] r_gain;
wire [15:0] g_gain;
wire [15:0] b_gain;

debayer_top_2to1 #(.BAYER_X_PHASE(1)) debayer_top
(
	.in_pclk		  (vid_clk_dvi2),//(i_mipi_rx_pclk ),
	.in_rstn		  (vid_rst_n	),
	
	.raw_vs_i		  (ch0_vs		      ),
	.raw_hs_i		  (ch0_hs		      ),
	.raw_de_i		  (ch0_de		      ),
	.raw_valid_i	(ch0_de	        ),
	.raw_datax4_i	({ch0_g,ch0_b}	), // Preserve the FIFO pair byte order.
	.r_gain       (|r_gain? r_gain:16'd256 ),
  .g_gain       (|g_gain? g_gain:16'd256 ),
  .b_gain       (|b_gain? b_gain:16'd256 ),
	.rgb_vs_o		  (rgb_vs         ),
	.rgb_hs_o		  (rgb_hs         ),
	.rgb_de_o		  (rgb_de         ),
	.rgb_valid_o	(rgb_valid      ),
	.rgb_datax2_o (rgb_datax2     )//b,g,r,b,g,r
);

//==============================================================================
// Sobel / Canny 边缘检测（2 像素/时钟）
//   输入：debayer 输出 rgb_vs/rgb_hs/rgb_de/rgb_valid/rgb_datax2（2 像素/时钟）
//   输出：edge_* 同格式，接到 HDMI(DVI) 发送通路
//   手动高阈值32..192，按键 +/-8；低阈值固定取高阈值的一半
//   分屏：SPLIT_PAIR = MAX_HRES/4 → 左右各半(单位:像素对, 480对=960像素)（左半原图 / 右半边缘），便于对比
//==============================================================================
wire [11:0] threshold_video_sync;
wire [1:0] edge_mode_request;
wire [1:0] edge_active_mode;
wire digit_mode_request,hand_mode_request;
video_controls #(.DEFAULT_VIEW(0),.EXTENDED_RECOGNITION(1),.DIGIT_FEATURE_CONTROLS(1),.HAND_RECOGNITION(1)) edge_controls (
  .i_clk(vid_clk_dvi2),.i_rst_n(vid_rst_n),
  .i_key0_n(i_key0_n),.i_key1_n(i_key1_n),.i_key2_n(i_key2_n),
   .o_threshold(threshold_video_sync),.o_mode(edge_mode_request),.o_view(view_request),
  .o_freeze(freeze_request),.o_step_sequence(step_sequence),.o_step_older(step_older),.o_digit_mode(digit_mode_request),.o_hand_mode(hand_mode_request)
);

wire        edge_vs;
wire        edge_hs;
wire        edge_de;
wire        edge_valid;
wire [47:0] edge_datax2;
wire [3:0] edge_classx2;
wire [15:0] edge_grayx2;
wire [11:0] edge_high_threshold;

// Debayer is BGR/BGR; both edge cores expect RGB/RGB.
wire [47:0] edge_rgbx2 = {rgb_datax2[31:24], rgb_datax2[39:32], rgb_datax2[47:40],
                         rgb_datax2[7:0], rgb_datax2[15:8], rgb_datax2[23:16]};
wire camera_vs,camera_hs,camera_de,camera_valid;
wire [47:0] camera_rgbx2;
wire [15:0] pyramid_seed_grayx2;
camera_smooth_2px #(.H_ACTIVE(MAX_HRES)) camera_preprocessing (
    .clk(vid_clk_dvi2),.rst_n(vid_rst_n),.in_vs(rgb_vs),.in_hs(rgb_hs),.in_de(rgb_de),.in_valid(rgb_valid),
    .rgbx2(edge_rgbx2),.out_vs(camera_vs),.out_hs(camera_hs),.out_de(camera_de),.out_valid(camera_valid),
    .smooth_rgbx2(camera_rgbx2),.pyramid_grayx2(pyramid_seed_grayx2));
wire pyramid_vs,pyramid_hs,pyramid_de,pyramid_valid;
wire [47:0] pyramid_rgbx2;
gaussian_pyramid_2px #(.WIDTH(MAX_HRES),.HEIGHT(MAX_VRES)) pyramid_denoising(
    .clk(vid_clk_dvi2),.rst_n(vid_rst_n),.in_vs(camera_vs),.in_hs(camera_hs),.in_de(camera_de),.in_valid(camera_valid),
    .rgbx2(camera_rgbx2),.gaussian_grayx2(pyramid_seed_grayx2),
    .out_vs(pyramid_vs),.out_hs(pyramid_hs),.out_de(pyramid_de),.out_valid(pyramid_valid),.out_rgbx2(pyramid_rgbx2));
contest_pipeline_2px #(.H_ACTIVE(MAX_HRES),.EDGE_THRESHOLD(EDGE_THRESHOLD)) edge_pipeline_inst (
  .i_clk(vid_clk_dvi2),.i_rst_n(vid_rst_n),.i_vs(pyramid_vs),.i_hs(pyramid_hs),.i_de(pyramid_de),.i_valid(pyramid_valid),
  .i_rgbx2(pyramid_rgbx2),.i_threshold(threshold_video_sync),.i_mode(edge_mode_request),
  .o_vs(edge_vs),.o_hs(edge_hs),.o_de(edge_de),.o_valid(edge_valid),
  .o_rgbx2(edge_datax2),.o_high_threshold(edge_high_threshold),.o_mode(edge_active_mode),.o_classx2(edge_classx2)
);

wire [47:0] aligned_rgbx2;
// Display/recognition luminance is exactly the aligned denoised color image.
rgb888_to_gray aligned_gray0(.i_r(aligned_rgbx2[23:16]),.i_g(aligned_rgbx2[15:8]),.i_b(aligned_rgbx2[7:0]),.o_gray(edge_grayx2[7:0]));
rgb888_to_gray aligned_gray1(.i_r(aligned_rgbx2[47:40]),.i_g(aligned_rgbx2[39:32]),.i_b(aligned_rgbx2[31:24]),.o_gray(edge_grayx2[15:8]));
rgb_align_2px #(.H_ACTIVE(MAX_HRES)) original_color_alignment (
  .i_clk(vid_clk_dvi2),.i_rst_n(vid_rst_n),.i_vs(pyramid_vs),.i_hs(pyramid_hs),.i_de(pyramid_de),.i_valid(pyramid_valid),
  .i_rgbx2(pyramid_rgbx2),.o_rgbx2(aligned_rgbx2)
);

wire [1:0] hand_skin,hand_contour;
wire [3:0] hand_contour_alpha;
hand_contour_2px #(.H_ACTIVE(MAX_HRES)) hand_segmentation(
    .clk(vid_clk_dvi2),.rst_n(vid_rst_n),.in_vs(pyramid_vs),.in_hs(pyramid_hs),.in_de(pyramid_de),.in_valid(pyramid_valid),
    .rgbx2(pyramid_rgbx2),.skin(hand_skin),.contour(hand_contour),.contour_alpha(hand_contour_alpha));
reg digit_mode_active,hand_mode_active,hand_mask_view_active,recognition_vs_d;
always @(posedge vid_clk_dvi2 or negedge vid_rst_n)begin
    if(!vid_rst_n)begin digit_mode_active<=0;hand_mode_active<=0;hand_mask_view_active<=0;recognition_vs_d<=0;end
    else begin recognition_vs_d<=edge_vs;if(edge_vs&&!recognition_vs_d)begin digit_mode_active<=digit_mode_request;hand_mode_active<=hand_mode_request;hand_mask_view_active<=view_request==0;end end
end
wire [1:0] recursive_edges;
wire recursive_active,recursive_good,recursive_fault;
wire [2:0] recursive_status;
wire [31:0] recursive_cycles;
wire [21:0] recursive_accepted;
canny_recursive_frame #(.WIDTH(MAX_HRES),.HEIGHT(MAX_VRES)) recursive_canny (
    .clk(core_clk),.rst_n(vid_rst_n),.video_clk(vid_clk_dvi2),.in_vs(edge_vs),.in_de(edge_de),
    .enable(freeze_request&&edge_active_mode==2&&!digit_mode_active),.source_valid(source_valid),
    .source_key({source_frame_id,edge_active_mode,edge_high_threshold}),.classes(edge_classx2),
    .exact_edges(recursive_edges),.exact_active(recursive_active),.video_good(recursive_good),
    .status(recursive_status),.processing_cycles(recursive_cycles),.accepted_pixels(recursive_accepted),.fault(recursive_fault),
    .awaddr(exact_axi_awaddr),
    .awlen(exact_axi_awlen),
    .awsize(exact_axi_awsize),
    .awvalid(exact_axi_awvalid),
    .awready(exact_axi_awready),
    .araddr(exact_axi_araddr),
    .arlen(exact_axi_arlen),
    .arsize(exact_axi_arsize),
    .arvalid(exact_axi_arvalid),
    .arready(exact_axi_arready),
    .wdata(exact_axi_wdata),
    .wstrb(exact_axi_wstrb),
    .wlast(exact_axi_wlast),
    .wvalid(exact_axi_wvalid),
    .wready(exact_axi_wready),
    .bvalid(exact_axi_bvalid),
    .bresp(exact_axi_bresp),
    .bready(exact_axi_bready),
    .rdata(exact_axi_rdata),
    .rlast(exact_axi_rlast),
    .rvalid(exact_axi_rvalid),
    .rready(exact_axi_rready),
    .rresp(exact_axi_rresp)
);
wire [1:0] processed_mode=hand_mode_active ? 2'd3 : recursive_active ? 2'd3 : edge_active_mode;
wire [47:0] processed_edges=hand_mode_active ?
    (hand_mask_view_active?{{24{hand_skin[1]}},{24{hand_skin[0]}}}:{{24{hand_contour[1]}},{24{hand_contour[0]}}}) :
    recursive_active ? {{24{recursive_edges[1]}},{24{recursive_edges[0]}}} : edge_datax2;
wire processed_source_valid=source_valid&&(!(freeze_request&&edge_active_mode==2&&!digit_mode_active)||recursive_good);
wire [34:0] exact_display_meta;
config_cdc #(.WIDTH(35)) exact_status_cdc (
    .i_src_clk(vid_clk_dvi2),.i_src_rst_n(vid_rst_n),.i_data({recursive_status,recursive_cycles}),
    .i_dst_clk(hdmi_tx_slow_clk),.i_dst_rst_n(vid_rst_n),.o_data(exact_display_meta),.o_ready()
);
reg [34:0] displayed_exact_meta;
always @(posedge hdmi_tx_slow_clk or negedge vid_rst_n) begin
    if(!vid_rst_n) displayed_exact_meta<=0;
    else if(comp_de_o&&comp_x_d==0&&comp_y_d==0) displayed_exact_meta<=exact_display_meta;
end

wire shape_valid,shape_busy;
wire [3:0] shape_class;
wire [31:0] shape_frame,shape_cycles;
wire [14:0] shape_config;
wire [7:0] shape_score,shape_margin,shape_reason;
wire [10:0] shape_ax,shape_ay,shape_bx,shape_by,shape_cx,shape_cy;
wire [2:0] shape_orientation;
wire [15:0] shape_cells;
wire [4:0] shape_components;
wire [1:0] shape_candidates;
wire [10:0] shape_x0,shape_y0,shape_x1,shape_y1;
wire [15:0] shape_dropped;
// 0.5-second sampling in the actual 74.25 MHz dual-pixel domain.
shape_engine_2px #(.WIDTH(MAX_HRES),.HEIGHT(MAX_VRES),.ROI_ENABLE(1),
    .SAMPLE_INTERVAL_CYCLES(37_125_000),.BLOCK_SHIFT(3),.COMPACT_ROI(1),.FEATURE_RECOGNITION(1),.ENABLE_EXTENDED(1),.CONFIG_BITS(15),.CLASS_BITS(4),.HAND_RECOGNITION(1),.HAND_FULL_HEIGHT(1)) u_shape_engine (
  .clk(vid_clk_dvi2),.rst_n(vid_rst_n),.in_vs(edge_vs),.in_de(edge_de),.edges({processed_edges[24],processed_edges[0]}),
  .grayx2(edge_grayx2),.digit_mode(digit_mode_active),.hand_skin(hand_skin),
  .source_valid(processed_source_valid),.source_id(source_frame_id),.config_id({digit_mode_active,processed_mode,edge_high_threshold}),
  .result_valid(shape_valid),.result_class(shape_class),.result_frame(shape_frame),.result_config(shape_config),
  .box_x0(shape_x0),.box_y0(shape_y0),.box_x1(shape_x1),.box_y1(shape_y1),
  .busy(shape_busy),.analysis_cycles(shape_cycles),.dropped_maps(shape_dropped),
  .result_reason(shape_reason),.vertex_ax(shape_ax),.vertex_ay(shape_ay),.vertex_bx(shape_bx),.vertex_by(shape_by),.vertex_cx(shape_cx),.vertex_cy(shape_cy),.result_score(shape_score),.result_margin(shape_margin),.result_orientation(shape_orientation),
  .result_cells(shape_cells),.result_components(shape_components),.result_candidates(shape_candidates)
);
wire [114:0] display_shape;
wire display_shape_ready;
config_cdc #(.WIDTH(115)) shape_result_cdc (
  .i_src_clk(vid_clk_dvi2),.i_src_rst_n(vid_rst_n),
  .i_data({shape_reason,shape_valid,shape_class,shape_frame,shape_config,shape_x0,shape_y0,shape_x1,shape_y1,shape_orientation,shape_score}),
  .i_dst_clk(hdmi_tx_slow_clk),.i_dst_rst_n(vid_rst_n),.o_data(display_shape),.o_ready(display_shape_ready)
);
wire [38:0] display_source;
wire display_source_ready;
config_cdc #(.WIDTH(39)) source_identity_cdc (
  .i_src_clk(vid_clk_dvi2),.i_src_rst_n(vid_rst_n),.i_data({processed_source_valid,source_frame_id,source_history}),
  .i_dst_clk(hdmi_tx_slow_clk),.i_dst_rst_n(vid_rst_n),.o_data(display_source),.o_ready(display_source_ready)
);

reg rgb_vs_r = 'd0;
always @( posedge hdmi_tx_slow_clk )
begin
  rgb_vs_r <= edge_vs;
end
assign pos_vs = {rgb_vs_r,edge_vs} == 2'b01;
reg vid_cnt = 'd0;
reg [7:0] hdmi_tx_rdata ;
reg [7:0] hdmi_tx_gdata ;
reg [7:0] hdmi_tx_bdata ;
reg hdmi_tx_vs;
reg hdmi_tx_hs;
reg hdmi_tx_de;
reg [7:0] comp_gray_pix;
reg [23:0] comp_original_rgb;
reg [1:0] comp_hand_alpha;
always @( posedge hdmi_tx_slow_clk )
begin
    if( pos_vs )
      vid_cnt <= 1'b1;
    else if( edge_de )
      vid_cnt <= ~vid_cnt ;

    if( vid_cnt ) begin
      {hdmi_tx_bdata,hdmi_tx_gdata,hdmi_tx_rdata} <= processed_edges[23:0];
      comp_gray_pix <= edge_grayx2[7:0];
      comp_original_rgb<=aligned_rgbx2[23:0];
      comp_hand_alpha<=hand_mode_active?hand_contour_alpha[1:0]:2'd0;
    end else begin
      {hdmi_tx_bdata,hdmi_tx_gdata,hdmi_tx_rdata} <= processed_edges[47:24];
      comp_gray_pix <= edge_grayx2[15:8];
      comp_original_rgb<=aligned_rgbx2[47:24];
      comp_hand_alpha<=hand_mode_active?hand_contour_alpha[3:2]:2'd0;
    end

  hdmi_tx_vs <= edge_vs;
  hdmi_tx_hs <= edge_hs;
  hdmi_tx_de <= edge_de;
end
// Frame-bound views, original RGB overlay and identity-checked recognition boxes.
wire comp_de_o,comp_hs_o,comp_vs_o;
wire [10:0] comp_x_d,comp_y_d;
wire [23:0] composited_rgb;
wire [1:0] display_view;
wire [3:0] display_shape_class;
wire display_recognition_ready;
wire [7:0] display_detection_age;
wire [31:0] displayed_frame;
video_compositor #(.WIDTH(MAX_HRES),.HEIGHT(MAX_VRES),.ROI_ENABLE(1),
    .LIVE_HOLD_ENABLE(1),.MAX_RESULT_AGE_FRAMES(60),.CONFIG_BITS(15),.CLASS_BITS(4),.CONTEST_SPLIT(1),.HAND_FULL_HEIGHT(1)) compositor (
  .clk(hdmi_tx_slow_clk),.rst_n(vid_rst_n),.in_vs(hdmi_tx_vs),.in_hs(hdmi_tx_hs),.in_de(hdmi_tx_de),
  .in_rgb(comp_original_rgb),.in_gray(comp_gray_pix),.in_edge(hdmi_tx_rdata[0]),.in_edge_alpha(comp_hand_alpha),.requested_view(osd_config[15:14]),
  .is_frozen(osd_config[16]),.source_valid(display_source_ready&&display_source[38]),.source_id(display_source[37:6]),.config_id({osd_config[17],osd_config[13:0]}),
  .result_valid(display_shape_ready&&display_shape[106]),.result_class(display_shape[105:102]),
  .result_frame(display_shape[101:70]),.result_config(display_shape[69:55]),
  .box_x0(display_shape[54:44]),.box_y0(display_shape[43:33]),.box_x1(display_shape[32:22]),.box_y1(display_shape[21:11]),
  .out_vs(comp_vs_o),.out_hs(comp_hs_o),.out_de(comp_de_o),.out_rgb(composited_rgb),.out_x(comp_x_d),.out_y(comp_y_d),
  .shape_age(display_detection_age),.active_view(display_view),.shape_class(display_shape_class),.shape_ready(display_recognition_ready),.displayed_frame(displayed_frame)
);
wire [7:0] comp_o_r=composited_rgb[23:16],comp_o_g=composited_rgb[15:8],comp_o_b=composited_rgb[7:0];
reg [5:0] display_history;
always @(posedge hdmi_tx_slow_clk or negedge vid_rst_n) begin
  if(!vid_rst_n) display_history<=0;
  else if(comp_de_o&&comp_x_d==0&&comp_y_d==0) display_history<=display_source[5:0];
end

// Transfer a stable frame configuration with a bundled-data handshake.
wire [17:0] osd_config;
wire osd_config_ready;
config_cdc #(.WIDTH(18),.RESET_VALUE({2'b0,2'd1,2'd0,12'd128})) osd_config_cdc (
  .i_src_clk(vid_clk_dvi2),.i_src_rst_n(vid_rst_n),.i_data({digit_mode_active,freeze_request,view_request,processed_mode,edge_high_threshold}),
  .i_dst_clk(hdmi_tx_slow_clk),.i_dst_rst_n(vid_rst_n),.o_data(osd_config),.o_ready(osd_config_ready)
);
reg [17:0] osd_display_config;
reg osd_vs_d;
always @(posedge hdmi_tx_slow_clk or negedge vid_rst_n) begin
  if(!vid_rst_n) begin osd_display_config<={2'b0,2'd1,2'd0,12'd128};osd_vs_d<=0;end
  else begin
    osd_vs_d<=comp_vs_o;
    if(comp_de_o&&comp_x_d==0&&comp_y_d==0&&osd_config_ready) osd_display_config<=osd_config;
  end
end

wire [7:0] osd_o_r;
wire [7:0] osd_o_g;
wire [7:0] osd_o_b;
wire osd_de_o,osd_hs_o,osd_vs_o;
wire [7:0] measured_fps;
video_fps_meter #(
  .CLK_HZ(148_500_000), .DEFAULT_FPS(0)
) video_fps_meter_inst (
  .i_clk(hdmi_tx_slow_clk), .i_rst_n(vid_rst_n),
  .i_vs(comp_vs_o), .o_fps(measured_fps)
);

contest_status_osd #(.DETECTION_OVERLAY(1),.CLASS_BITS(4),.EXTENDED_RECOGNITION(1),.HAND_RECOGNITION(1)) threshold_osd_inst (
  .i_clk(hdmi_tx_slow_clk), .i_rst_n(vid_rst_n), .i_de(comp_de_o),
  .i_hs(comp_hs_o), .i_vs(comp_vs_o),
  .i_x(comp_x_d), .i_y(comp_y_d),
  .i_threshold(osd_display_config[11:0]), .i_fps(measured_fps), .i_mode(osd_display_config[13:12]),
  .i_exact_status(displayed_exact_meta[34:32]),.i_exact_cycles(displayed_exact_meta[31:0]),
  .i_freeze(osd_display_config[16]),.i_view(display_view),.i_frame(displayed_frame),
  .i_age(display_history[5:4]),.i_history_count(display_history[3:1]),.i_fault(display_history[0]),
  .i_shape_reason(display_shape[114:107]),.i_hand_raw(display_shape[7:0]),.i_digit_mode(osd_display_config[17]),.i_shape_ready(display_recognition_ready),.i_shape_class(display_shape_class),.i_shape_age(display_detection_age),
  .i_r(comp_o_r), .i_g(comp_o_g), .i_b(comp_o_b),
  .o_r(osd_o_r), .o_g(osd_o_g), .o_b(osd_o_b),
  .o_de(osd_de_o), .o_hs(osd_hs_o), .o_vs(osd_vs_o)
);

//==============================================================================
// MIPI DSI
//==============================================================================
// signal 

reg		[25:0]	r_rst_cnt;

wire	[31:0]	w_axi_rdata;
wire			w_axi_awready;
wire			w_axi_wready;
wire			w_axi_arready;
wire			w_axi_rvalid;
wire			w_axi_bvalid;

wire	[6:0]	w_axi_awaddr;
wire			w_axi_awvalid;
wire	[31:0]	w_axi_wdata;
wire			w_axi_wvalid;
wire			w_axi_bready;
wire	[6:0]	w_axi_araddr;
wire			w_axi_arvalid;
wire			w_axi_rready;

wire			w_confdone;
assign w_confdone = 1'b1;

assign  LCD_POWER 			= i_arstn;
assign	LCD_RST_P	      = ~w_arstn;//~r_rst_cnt[23]; LCD复位先释放，然后再释放MIPI 的复位
assign	mipi_dp_clk_RST		= ~i_arstn;
assign	mipi_dp_data0_RST	= ~i_arstn;
assign	mipi_dp_data1_RST	= ~i_arstn;
assign	mipi_dp_data2_RST	= ~i_arstn;
assign	mipi_dp_data3_RST	= ~i_arstn;
////////////////////////////////////////////////////////////////
always@(posedge i_mipi_clk or  negedge w_arstn )
begin
  if ( !w_arstn ) begin
    r_rst_cnt	<= 'd0;
  end else 		
    r_rst_cnt	<= r_rst_cnt[25] ? r_rst_cnt :r_rst_cnt + 1'b1;
end

wire axi_rst_n = r_rst_cnt[25];

reg [26:0] dly_cnt = 'd0;

always @( posedge vid_clk_dvi2 or negedge w_arstn )
begin
  if( !w_arstn )
    dly_cnt <= 'd0;
  else if( w_confdone )
    dly_cnt <= dly_cnt[26] ? dly_cnt :(dly_cnt + 1'b1);
  else 
    dly_cnt <= 'd0;
end 

assign vid_rst_n = dly_cnt[26];




wire hs;
wire vs;
wire de;
wire [7:0] rgb_r;
wire [7:0] rgb_g;
wire [7:0] rgb_b;
  
  // color_bar_rgb #(
  // .HS_POLORY 		(1'b1		),
  // .VS_POLORY 		(1'b1		),
  // .H_FRONT_PORCH 	(HFP		),///2
  // .H_SYNC 		(HSP		),//
  // .H_VALID 		(MAX_HRES	),//
  // .H_BACK_PORCH 	(HBP		),//
  // .V_FRONT_PORCH 	(VFP		),
  // .V_SYNC 		(VSP		),
  // .V_VALID 		(MAX_VRES	),
  // .V_BACK_PORCH 	(VBP		),
  // .TEST_MODE 		(2'd2)
  // )u_color_bar_rgb1(
  // /*i*/.clk	(vid_clk_dvi2),//(vid_clk),
  // /*i*/.rst_n	(vid_rst_n),
  // /*o*/.hs	(hs),
  // /*o*/.vs	(vs),
  // /*o*/.de	(de),
  // // /*O*/.h_cnt (h_cnt),
  // // /*O*/.v_cnt (v_cnt),
  // /*o*/.rgb_r	(rgb_r),    //像素数据、红色分量
  // /*o*/.rgb_g	(rgb_g),    //像素数据、绿色分量
  // /*o*/.rgb_b (rgb_b)    //像素数据、蓝色分量
  
  // );

//=================================================================================
//hdmi tx ctrl 
//=================================================================================
wire                            video_hs;
wire                            video_vs;
wire                            video_de;
wire[7:0]                       video_r;
wire[7:0]                       video_g;
wire[7:0]                       video_b;

assign tmds_tx_data0_TX_OE = 1'b1;
assign tmds_tx_data1_TX_OE = 1'b1;
assign tmds_tx_data2_TX_OE = 1'b1;
assign tmds_tx_clk_TX_OE   = 1'b1;

assign tmds_tx_data0_TX_RST = 1'b0;
assign tmds_tx_data1_TX_RST = 1'b0;
assign tmds_tx_data2_TX_RST = 1'b0;
assign tmds_tx_clk_TX_RST   = 1'b0;

// 	  color_bar color_bar_m0(
// 	.clk(hdmi_tx_slow_clk),
// 	.rst(~vid_rst_n),
// 	.hs(video_hs),
// 	.vs(video_vs),
// 	.de(video_de),
// 	.rgb_r(video_r),
// 	.rgb_g(video_g),
// 	.rgb_b(video_b)
// );

wire [9:0] tmds_data0;
wire [9:0] tmds_data1;
wire [9:0] tmds_data2;
wire [9:0] tmds_clk ;
wire [7:0] gamma_rdata ;
wire [7:0] gamma_gdata ;
wire [7:0] gamma_bdata ;
wire gamma_valid;
wire gamma_hs;
wire gamma_vs;
wire gamma_sel;

wire [7:0] con_rdata ;
wire [7:0] con_gdata ;
wire [7:0] con_bdata ;
wire con_de;
wire con_hs;
wire con_vs;
wire con_sel;

wire [7:0] BRIGHT_SIG    ;
wire CONTRAST_SIG_G;
wire CONTRAST_SIG_R;
wire [7:0] CONTRAST_G    ;
wire CONTRAST_SIG_B;
wire [7:0] BRIGHT        ;
wire [7:0] CONTRAST_R    ;


wire CONTRAST_B    ;


gamma_correction
#(
	.DATA_WIDTH		(8),
	.GAMMA_CURVE	("./rtl/gamma_conrrection/2P2.mem")
)
inst_gamma_correction
(
	.i_pclk		(hdmi_tx_slow_clk),
	.i_rstn		(vid_rst_n),
	
	.i_red		(hdmi_tx_rdata),//(con_rdata  ),//
	.i_green	(hdmi_tx_gdata),//(con_gdata  ),//
	.i_blue		(hdmi_tx_bdata),//(con_bdata  ),//
  .i_valid	(hdmi_tx_de   ),//(con_de     ),//
  .i_hs     (hdmi_tx_hs   ),//(con_hs     ),//
  .i_vs     (hdmi_tx_vs   ),//(con_vs     ),//
	.o_blue		(gamma_bdata		),
  .o_green	(gamma_gdata	  ),
	.o_red		(gamma_rdata		),
	.o_valid	(gamma_valid	  ),
  .o_hs     (gamma_hs       ),
  .o_vs     (gamma_vs       )
);

dvi_encoder dvi_encoder_m0
(
	.pixelclk      		(hdmi_tx_slow_clk          ),// system clock
	.rst_p         		(~vid_rst_n      ),// reset
	.i_bdata(osd_o_b),//(hdmi_tx_rdata ),//(video_b            ),//(bdata_in	),   //
	.i_gdata(osd_o_g),//(hdmi_tx_gdata ),//(video_g            ),//(gdata_in	),   //   
	.i_rdata(osd_o_r),//(hdmi_tx_bdata ),//(video_r            ),//(rdata_in	),   //   
  .i_de(osd_de_o),//(hdmi_tx_de    ),//(video_de           ),//(rx_de		  ),   //
	.i_hs(osd_hs_o),//(video_hs           ),//(rx_hsync	),   //   
	.i_vs(osd_vs_o),//(video_vs           ),//(rx_vsync	),   //  
	
  .video_format     (video_format), //// 00 = RGB, 01 = YCbCr 4:2:2, 10 = YCbCr 4:4:4
  .video_VIC        (0),
	.audio_L			    (audio_L),
  .audio_R			    (audio_R),
  .audio_valid		  (audio_valid),
  .audio_N                (6144),     //(20'h01880),//     
  .audio_CTS              (148500),      //(20'h28488),//      
  .audio_sample_frequency (audio_samp_freq),    //(3'b000),// 
  .audio_word_length      ({audio_samp_word_len,audio_max_word_length}),//(4'b1011),//

	.tmds_data0    		(tmds_data0),
  .tmds_data1    		(tmds_data1),
  .tmds_data2    		(tmds_data2),
  .tmds_clk      	  (tmds_clk  )
);
assign tmds_tx_clk_TX_DATA   = ~tmds_clk;
assign tmds_tx_data0_TX_DATA = ~tmds_data0;
assign tmds_tx_data1_TX_DATA = ~tmds_data1;
assign tmds_tx_data2_TX_DATA = ~tmds_data2;

wire [15:0] detection_debug_data;wire detection_debug_sync;
detection_telemetry #(.FEATURE_PACKET(1)) detection_readout(
    .clk(vid_clk_dvi2),.rst_n(vid_rst_n),.result_valid(shape_valid),.source_valid(processed_source_valid),.cal_done(cal_done),.busy(shape_busy),
    .kind(shape_class),.result_frame(shape_frame),.source_frame(source_frame_id),.config_id(shape_config),
    .x0(shape_x0),.y0(shape_y0),.x1(shape_x1),.y1(shape_y1),.orientation(shape_orientation),.error_score(shape_score),.margin(shape_margin),
    .ax(shape_ax),.ay(shape_ay),.bx(shape_bx),.by(shape_by),.cx(shape_cx),.cy(shape_cy),.reason(shape_reason),.cells(shape_cells),.components(shape_components),.candidates(shape_candidates),.data(detection_debug_data),.sync(detection_debug_sync));
// Existing LA0 probes now carry coherent detection packets; no debug-core RAM growth.
debug_edb_top debug_edb_top_inst (
    .bscan_CAPTURE      ( jtag_inst1_CAPTURE  ),
    .bscan_DRCK         ( jtag_inst1_DRCK     ),
    .bscan_RESET        ( jtag_inst1_RESET    ),
    .bscan_RUNTEST      ( jtag_inst1_RUNTEST  ),
    .bscan_SEL          ( jtag_inst1_SEL      ),
    .bscan_SHIFT        ( jtag_inst1_SHIFT    ),
    .bscan_TCK          ( jtag_inst1_TCK      ),
    .bscan_TDI          ( jtag_inst1_TDI      ),
    .bscan_TMS          ( jtag_inst1_TMS      ),
    .bscan_UPDATE       ( jtag_inst1_UPDATE   ),
    .bscan_TDO          ( jtag_inst1_TDO      ),
    .vio0_clk           ( vid_clk_dvi2        ),
    .vio0_r_gain        ( r_gain              ),
    .vio0_g_gain        ( g_gain              ),
    .vio0_b_gain        ( b_gain              ),

    .vio0_gamma_sel     (gamma_sel),
    .la0_clk            ( vid_clk_dvi2        ),
    .la0_ch0_g          ( detection_debug_data[7:0] ),
    .la0_ch0_b          ( detection_debug_data[15:8] ),
    .la0_ch0_de         ( detection_debug_sync ),
    .la0_cal_done       ( cal_done            )
);

endmodule
