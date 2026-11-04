// Native-resolution snapshot Canny. Capture -> DDR DFS -> flush -> display.
// 4 bits/pixel at 0x01000000; RAW history uses the first 16 MiB.
module canny_recursive_frame #(
    parameter integer WIDTH=1920,HEIGHT=1080,
    parameter integer PIXELS=WIDTH*HEIGHT,PAIRS=PIXELS/2,WORDS=(PIXELS+31)/32,
    parameter integer AB=$clog2(PIXELS),
    parameter [31:0] BASE=32'h01000000
) (
    input wire clk,rst_n,video_clk,
    input wire in_vs,in_de,enable,source_valid,
    input wire [45:0] source_key,
    input wire [3:0] classes,
    output wire [1:0] exact_edges,
    output wire exact_active,video_good,
    output wire [2:0] status,
    output wire [31:0] processing_cycles,
    output wire [21:0] accepted_pixels,
    output wire fault,
    output wire [31:0] awaddr,araddr,
    output wire [7:0] awlen,arlen,
    output wire [2:0] awsize,arsize,
    output wire awvalid,wvalid,wlast,bready,arvalid,rready,
    output wire [127:0] wdata,
    output wire [15:0] wstrb,
    input wire awready,wready,bvalid,arready,rvalid,rlast,
    input wire [1:0] bresp,rresp,
    input wire [127:0] rdata
);
    localparam WAIT=0,RESET_CAPTURE=1,SETTLE=2,ARMED=3,CAPTURE=4,TRACE=5,FLUSH=6,READY=7,READ_RESET=8,READ_SETTLE=9,FAIL=10;
    reg [3:0] state;
    reg [5:0] settle_count;
    reg [45:0] work_key,result_key;
    reg result_valid,write_start,read_start,engine_start,cache_flush,cache_invalidate;
    reg core_fault,write_finished,reader_busy,reader_error_seen;
    reg [31:0] done_cycles;
    reg [21:0] done_accepted;
    wire [46:0] desired;
    wire desired_ready;
    config_cdc #(.WIDTH(47)) request_mailbox(
        .i_src_clk(video_clk),.i_src_rst_n(rst_n),.i_data({enable&&source_valid,source_key}),
        .i_dst_clk(clk),.i_dst_rst_n(rst_n),.o_data(desired),.o_ready(desired_ready));
    wire [46:0] capture_arm;
    wire arm_ready;
    config_cdc #(.WIDTH(47)) capture_mailbox(
        .i_src_clk(clk),.i_src_rst_n(rst_n),.i_data({state==ARMED,work_key}),
        .i_dst_clk(video_clk),.i_dst_rst_n(rst_n),.o_data(capture_arm),.o_ready(arm_ready));
    reg capture_started,capture_complete,capture_fault,capturing,video_vs_d,first_line,video_de_d;
    reg [21:0] capture_pairs;
    reg [3:0] capture_lane;
    reg [127:0] pack,packed_word;
    reg [45:0] captured_key;
    reg pack_write;
    wire write_full;
    wire [7:0] pair_tags={2'b00,classes[3:2],2'b00,classes[1:0]};
    reg [127:0] next_pack;
    always @* begin next_pack=pack;next_pack[capture_lane*8+:8]=pair_tags;end
    wire start_capture=in_de&&!video_de_d&&first_line&&enable&&source_valid&&arm_ready&&capture_arm[46]&&capture_arm[45:0]==source_key;
    always @(posedge video_clk or negedge rst_n) begin
        if(!rst_n) begin
            capture_started<=0;capture_complete<=0;capture_fault<=0;capturing<=0;video_vs_d<=0;video_de_d<=0;first_line<=1;
            capture_pairs<=0;capture_lane<=0;pack<=0;packed_word<=0;pack_write<=0;captured_key<=0;
        end else begin
            video_vs_d<=in_vs;video_de_d<=in_de;pack_write<=0;
            if(pack_write&&write_full) capture_fault<=1;
            if(in_vs&&!video_vs_d) begin
                first_line<=1;
                if(capturing) begin capture_fault<=1;capturing<=0;capture_complete<=~capture_complete;end
            end
            if(in_de) first_line<=0;
            if(start_capture&&!capturing) begin
                capturing<=1;capture_started<=~capture_started;capture_pairs<=1;capture_lane<=1;
                pack<={120'd0,pair_tags};captured_key<=source_key;
            end else if(capturing&&in_de) begin
                if(!source_valid||source_key!=captured_key) capture_fault<=1;
                pack<=next_pack;capture_pairs<=capture_pairs+1'b1;capture_lane<=capture_lane+1'b1;
                if(capture_lane==15||capture_pairs==PAIRS-1) begin
                    packed_word<=next_pack;pack_write<=1;pack<=0;
                    if(write_full) capture_fault<=1;
                end
                if(capture_pairs==PAIRS-1) begin capturing<=0;capture_complete<=~capture_complete;end
            end
        end
    end
    (* async_reg="true" *) reg [2:0] started_sync,complete_sync;
    (* async_reg="true" *) reg [1:0] capture_fault_sync;
    reg capture_done_seen;
    wire start_event=started_sync[2]!=capture_done_seen;
    reg completion_seen;
    reg capture_finished;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin started_sync<=0;complete_sync<=0;capture_fault_sync<=0;end
        else begin started_sync<={started_sync[1:0],capture_started};complete_sync<={complete_sync[1:0],capture_complete};capture_fault_sync<={capture_fault_sync[0],capture_fault};end
    end
    wire [31:0] cap_awaddr;
    wire [7:0] cap_awlen;
    wire [2:0] cap_awsize;
    wire cap_awvalid,cap_wvalid,cap_wlast,cap_bready,write_done,write_error;
    wire [127:0] cap_wdata;
    wire [15:0] cap_wstrb;
    ddr_wr_buffer #(.AXI_DATA_WIDTH(128),.AXI_ADDR_WIDTH(32),.WR_FIFO_DEPTH(256),.BURST_LEN(127)) capture_dma(
        .axi_clk(clk),.rst_n(rst_n),.wr_start(write_start),.start_addr(BASE),.total_burst_len(25'(WORDS)),.bank_sw_ack(1'b0),
        .wr_fifo_rst_p(state==RESET_CAPTURE),.wr_fifo_wrclk(video_clk),.wr_fifo_wren(pack_write),.wr_fifo_wrfull(write_full),.wr_fifo_wrdata(packed_word),
        .awaddr(cap_awaddr),.awlen(cap_awlen),.awsize(cap_awsize),.awvalid(cap_awvalid),.awready(awready&&state==CAPTURE),
        .wdata(cap_wdata),.wstrb(cap_wstrb),.wvalid(cap_wvalid),.wlast(cap_wlast),.wready(wready&&state==CAPTURE),
        .bid(6'd0),.bvalid(bvalid&&state==CAPTURE),.bresp(bresp),.bready(cap_bready),.frame_done(write_done),.frame_error(write_error));
    wire mem_valid,mem_write,mem_ready,engine_busy,engine_done,engine_error;
    wire [AB-1:0] mem_addr;
    wire [3:0] mem_wdata,mem_rdata;
    wire [AB:0] engine_accepted;
    wire [31:0] engine_cycles;
    canny_hysteresis_exact #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) engine(
        .clk(clk),.rst_n(rst_n),.start(engine_start),.busy(engine_busy),.done(engine_done),.error(engine_error),
        .mem_valid(mem_valid),.mem_write(mem_write),.mem_addr(mem_addr),.mem_wdata(mem_wdata),.mem_ready(mem_ready),.mem_rdata(mem_rdata),
        .accepted_pixels(engine_accepted),.cycles(engine_cycles));
    wire cache_busy,cache_done,cache_fault;
    wire [31:0] cache_awaddr,cache_araddr;
    wire cache_awvalid,cache_wvalid,cache_wlast,cache_bready,cache_arvalid,cache_rready;
    wire [127:0] cache_wdata;
    wire cache_selected=state==TRACE||state==FLUSH||state==FAIL;
    canny_ddr_cache #(.PIXEL_BITS(AB),.BASE(BASE)) cache(
        .clk(clk),.rst_n(rst_n),.invalidate(cache_invalidate),.flush_start(cache_flush),
        .req_valid(mem_valid&&state==TRACE),.req_write(mem_write),.req_addr(mem_addr),.req_wdata(mem_wdata),.req_ready(mem_ready),.req_rdata(mem_rdata),
        .busy(cache_busy),.flush_done(cache_done),.fault(cache_fault),.hits(),.misses(),
        .awaddr(cache_awaddr),.awvalid(cache_awvalid),.wvalid(cache_wvalid),.wlast(cache_wlast),.wdata(cache_wdata),.bready(cache_bready),
        .araddr(cache_araddr),.arvalid(cache_arvalid),.rready(cache_rready),
        .awready(awready&&cache_selected),.wready(wready&&cache_selected),.bvalid(bvalid&&cache_selected),.bresp(bresp),
        .arready(arready&&cache_selected),.rvalid(rvalid&&cache_selected),.rlast(rlast),.rresp(rresp),.rdata(rdata));
    wire [7:0] read_request;
    wire [7:0] read_request_axi;
    reg [7:0] read_ack,read_seen;
    config_cdc #(.WIDTH(8)) read_request_mailbox(
        .i_src_clk(video_clk),.i_src_rst_n(rst_n),.i_data(read_request),
        .i_dst_clk(clk),.i_dst_rst_n(rst_n),.o_data(read_request_axi),.o_ready());
    wire [53:0] read_ack_video;
    config_cdc #(.WIDTH(54)) read_ack_mailbox(
        .i_src_clk(clk),.i_src_rst_n(rst_n),.i_data({read_ack,result_key}),
        .i_dst_clk(video_clk),.i_dst_rst_n(rst_n),.o_data(read_ack_video),.o_ready());
    wire [31:0] stream_araddr;
    wire [7:0] stream_arlen;
    wire [2:0] stream_arsize;
    wire stream_arvalid,stream_rready,read_done,read_error,fifo_empty,fifo_valid,fifo_read,stream_fault;
    wire [127:0] fifo_data;
    ddr_rd_buffer #(.AXI_DATA_WIDTH(128),.AXI_ADDR_WIDTH(32),.RD_FIFO_DEPTH(256),.BURST_LEN(127)) display_dma(
        .axi_clk(clk),.axi_clk_rst_n(rst_n),.start(read_start),.start_addr(BASE),.burst_len(25'(WORDS)),.bank_sw_ack(1'b0),
        .rd_fifo_rdclk(video_clk),.rd_fifo_rst_p(state==READ_RESET),.rd_fifo_rdvalid(fifo_valid),.rd_fifo_rddata(fifo_data),.rd_fifo_rdempty(fifo_empty),.rd_fifo_rden(fifo_read),
        .araddr(stream_araddr),.arlen(stream_arlen),.arsize(stream_arsize),.arvalid(stream_arvalid),.arready(arready&&!cache_selected),
        .rid(6'd0),.rdata(rdata),.rlast(rlast),.rvalid(rvalid&&!cache_selected),.rready(stream_rready),.rresp(rresp),.frame_done(read_done),.frame_error(read_error));
    wire [105:0] video_meta;
    reg [2:0] state_code;
    always @* begin
        case(state)
            RESET_CAPTURE,SETTLE,ARMED,CAPTURE:state_code=1;
            TRACE:state_code=2;FLUSH:state_code=3;
            READY,READ_RESET,READ_SETTLE:state_code=4;
            FAIL:state_code=5;
            default:state_code=0;
        endcase
    end
    config_cdc #(.WIDTH(106)) status_mailbox(
        .i_src_clk(clk),.i_src_rst_n(rst_n),
        .i_data({state_code,result_valid,!reader_busy&&state==READY,core_fault||reader_error_seen,result_key,state==TRACE ? engine_cycles : done_cycles,done_accepted}),
        .i_dst_clk(video_clk),.i_dst_rst_n(rst_n),.o_data(video_meta),.o_ready());
    canny_tag_stream_2px #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) stream(
        .clk(video_clk),.rst_n(rst_n),.in_vs(in_vs),.in_de(in_de),.enable(enable),.source_valid(source_valid),.source_key(source_key),.external_fault(video_meta[100]),
        .result_valid(video_meta[102]),.reader_idle(video_meta[101]),.result_key(video_meta[99:54]),
        .ack_sequence(read_ack_video[53:46]),.ack_key(read_ack_video[45:0]),.request_sequence(read_request),
        .fifo_empty(fifo_empty),.fifo_valid(fifo_valid),.fifo_data(fifo_data),.fifo_read(fifo_read),.edges(exact_edges),.exact_active(exact_active),.fault(stream_fault));
    assign status=fault ? 3'd5 : !enable ? 3'd0 : video_meta[105:103];
    assign processing_cycles=video_meta[53:22];
    assign accepted_pixels=video_meta[21:0];
    assign fault=video_meta[100]||stream_fault;
    assign video_good=!fault;
    assign awaddr=state==CAPTURE ? cap_awaddr : cache_awaddr;
    assign awlen=state==CAPTURE ? cap_awlen : 8'd0;
    assign awsize=3'd4;
    assign awvalid=state==CAPTURE ? cap_awvalid : cache_selected&&cache_awvalid;
    assign wdata=state==CAPTURE ? cap_wdata : cache_wdata;
    assign wstrb=state==CAPTURE ? cap_wstrb : 16'hffff;
    assign wvalid=state==CAPTURE ? cap_wvalid : cache_selected&&cache_wvalid;
    assign wlast=state==CAPTURE ? cap_wlast : cache_wlast;
    assign bready=state==CAPTURE ? cap_bready : cache_selected&&cache_bready;
    assign araddr=cache_selected ? cache_araddr : stream_araddr;
    assign arlen=cache_selected ? 8'd0 : stream_arlen;
    assign arsize=3'd4;
    assign arvalid=cache_selected ? cache_arvalid : stream_arvalid;
    assign rready=cache_selected ? cache_rready : stream_rready;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=WAIT;settle_count<=0;work_key<=0;result_key<=0;result_valid<=0;write_start<=0;read_start<=0;
            engine_start<=0;cache_flush<=0;cache_invalidate<=0;core_fault<=0;write_finished<=0;reader_busy<=0;reader_error_seen<=0;
            done_cycles<=0;done_accepted<=0;capture_done_seen<=0;completion_seen<=0;capture_finished<=0;read_ack<=0;read_seen<=0;
        end else begin
            write_start<=0;read_start<=0;engine_start<=0;cache_flush<=0;cache_invalidate<=0;
            if(reader_busy&&rvalid&&rready&&rresp!=0&&!cache_selected) reader_error_seen<=1;
            if(read_done) begin reader_busy<=0;if(read_error||reader_error_seen||(rvalid&&rready&&rresp!=0)) core_fault<=1;end
            if(complete_sync[2]!=completion_seen) begin completion_seen<=complete_sync[2];capture_finished<=1;end
            if(cache_fault||capture_fault_sync[1]||core_fault) begin
                core_fault<=1;result_valid<=0;
                // A capture DMA must finish any admitted burst before it is disconnected.
                if(state!=CAPTURE||write_done||write_finished) state<=FAIL;
            end
            else case(state)
                WAIT,READY:begin
                    if(desired_ready&&desired[46]&&(!result_valid||desired[45:0]!=result_key)&&!reader_busy) begin
                        work_key<=desired[45:0];result_valid<=0;settle_count<=0;state<=RESET_CAPTURE;cache_invalidate<=1;
                    end else if(state==READY&&read_request_axi!=read_seen&&!reader_busy) begin
                        read_seen<=read_request_axi;settle_count<=0;state<=READ_RESET;
                    end
                end
                RESET_CAPTURE:if(settle_count==15) begin settle_count<=0;state<=SETTLE;end else settle_count<=settle_count+1'b1;
                SETTLE:if(settle_count==15) begin state<=ARMED;capture_finished<=0;write_finished<=0;end else settle_count<=settle_count+1'b1;
                ARMED:if(start_event) begin capture_done_seen<=started_sync[2];write_start<=1;state<=CAPTURE;end
                    else if(desired[46]&&desired[45:0]!=work_key) begin work_key<=desired[45:0];settle_count<=0;state<=RESET_CAPTURE;end
                CAPTURE:begin
                    if(write_done) begin write_finished<=1;if(write_error) core_fault<=1;end
                    if(write_finished&&capture_finished&&!write_error) begin engine_start<=1;state<=TRACE;end
                end
                TRACE:if(engine_error) core_fault<=1;
                    else if(engine_done) begin done_cycles<=engine_cycles;done_accepted<=engine_accepted;cache_flush<=1;state<=FLUSH;end
                FLUSH:if(cache_done) begin result_key<=work_key;result_valid<=1;state<=READY;end
                READ_RESET:if(settle_count==15) begin settle_count<=0;state<=READ_SETTLE;end else settle_count<=settle_count+1'b1;
                READ_SETTLE:if(settle_count==15) begin read_start<=1;reader_busy<=1;read_ack<=read_seen;state<=READY;end else settle_count<=settle_count+1'b1;
                FAIL:;
                default:begin core_fault<=1;state<=FAIL;end
            endcase
        end
    end
endmodule
