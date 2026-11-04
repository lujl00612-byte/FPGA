// Block-OR edge map, exact 8-connected components, bounded single-target classifier.
// Analysis runs on a completed bank while the next frame uses the other bank.
// 0 UNKNOWN, 1 CIRCLE, 2 RECTANGLE, 3 MULTIPLE/LIMIT; extended: 4 TRIANGLE, 5..14 DIGIT0..9.
// Shapes use geometric rules; digits use fixed printed-font exemplars.
module shape_engine_2px #(
    parameter integer WIDTH=1920,HEIGHT=1080,BLOCK_SHIFT=4,
    parameter integer MIN_SIZE=12,MIN_CELLS=20,
    parameter integer ROI_ENABLE=0,
    parameter integer ROI_X0=WIDTH/4,ROI_Y0=HEIGHT/4,
    parameter integer ROI_X1=WIDTH/4+WIDTH/2-1,ROI_Y1=HEIGHT/4+HEIGHT/2-1,
    parameter integer SAMPLE_INTERVAL_CYCLES=0,
    parameter integer ENABLE_EXTENDED=0,CONFIG_BITS=14,CLASS_BITS=2,
    parameter integer DIGIT_THRESHOLD=128,FEATURE_RECOGNITION=0,COMPACT_ROI=0,HAND_RECOGNITION=0,
    parameter integer HAND_MIN_BLOCK_PIXELS=4,HAND_FULL_HEIGHT=0
) (
    input wire clk,rst_n,in_vs,in_de,
    input wire [1:0] edges,
    input wire [15:0] grayx2,
    input wire [1:0] hand_skin,
    input wire digit_mode,
    input wire source_valid,
    input wire [31:0] source_id,
    input wire [CONFIG_BITS-1:0] config_id,
    output reg result_valid,
    output reg [CLASS_BITS-1:0] result_class,
    output reg [31:0] result_frame,
    output reg [CONFIG_BITS-1:0] result_config,
    output reg [10:0] box_x0,box_y0,box_x1,box_y1,
    output wire busy,
    output reg [31:0] analysis_cycles,
    output reg [15:0] dropped_maps,
    output reg [7:0] result_score,result_margin,
    output reg [2:0] result_orientation,
    output reg [15:0] result_cells,
    output reg [4:0] result_components,
    output reg [1:0] result_candidates,
    output reg [7:0] result_reason,
    output reg [10:0] vertex_ax,vertex_ay,vertex_bx,vertex_by,vertex_cx,vertex_cy
);
    localparam integer BLOCK=1<<BLOCK_SHIFT;
    localparam integer MAP_X0=COMPACT_ROI&&ROI_ENABLE?ROI_X0:0,MAP_Y0=COMPACT_ROI&&ROI_ENABLE?ROI_Y0:0;
    localparam integer MAP_X1=COMPACT_ROI&&ROI_ENABLE?ROI_X1:WIDTH-1,MAP_Y1=COMPACT_ROI&&ROI_ENABLE?ROI_Y1:HEIGHT-1;
    localparam integer NORMAL_GH=(MAP_Y1-MAP_Y0+BLOCK)/BLOCK;
    localparam integer GW=(MAP_X1-MAP_X0+BLOCK)/BLOCK;
    localparam integer GH=HAND_FULL_HEIGHT?(HEIGHT+BLOCK-1)/BLOCK:NORMAL_GH;
    localparam integer CELLS=GW*GH;
    localparam integer AW=CELLS<=2 ? 1 : $clog2(CELLS);
    localparam integer CW=$clog2((GW>GH ? GW : GH)+1);
    localparam integer QW=HAND_FULL_HEIGHT?AW:2*CW;
    localparam [4:0] IDLE=0,CLEAR=1,SCAN_REQ=2,SCAN_WAIT=3,SCAN_EVAL=4,
        POP_REQ=5,POP_WAIT=6,POP_EVAL=7,NEIGH_REQ=8,NEIGH_WAIT=9,NEIGH_EVAL=10,
        FEATURE_INIT=11,FEATURE_REQ=12,FEATURE_WAIT=13,FEATURE_EVAL=14,DONE=15,
        DIGIT_REQ=16,DIGIT_WAIT=17,DIGIT_EVAL=18,DIGIT_ASPECT=19,DIGIT_START=20,DIGIT_MATCH=21;
    reg [3:0] pending_hand;
    reg pending_hand_valid,hand_confirmed;
    reg [31:0] pending_hand_frame;
    reg [CONFIG_BITS-1:0] pending_hand_config;
    reg [4:0] state;
    assign busy=state!=IDLE;
    reg capture_bank,processing_bank,vs_d,de_d;
    reg [10:0] px,py;
    reg [21:0] pair_count;
    reg [GW-1:0] columns;
    reg [31:0] capture_frame,work_frame;
    reg [CONFIG_BITS-1:0] capture_config,work_config;
    reg capture_digit_mode,work_digit_mode;
    // Reserved digit+EXACT configuration encodes HANDS without widening old CDCs.
    wire capture_hand=HAND_RECOGNITION&&(config_id>>12)==7;
    wire work_hand=HAND_RECOGNITION&&(work_config>>12)==7;
    reg capture_valid;
    localparam integer TIMER_BITS=SAMPLE_INTERVAL_CYCLES<2 ? 1 : $clog2(SAMPLE_INTERVAL_CYCLES+1);
    reg [TIMER_BITS-1:0] sample_timer;
    wire sample_due=SAMPLE_INTERVAL_CYCLES==0||sample_timer>=SAMPLE_INTERVAL_CYCLES-1;
    wire [10:0] capture_y0=HAND_FULL_HEIGHT&&capture_hand?0:MAP_Y0;
    wire [10:0] capture_y1=HAND_FULL_HEIGHT&&capture_hand?HEIGHT-1:MAP_Y1;
    wire [10:0] work_y0=HAND_FULL_HEIGHT&&work_hand?0:MAP_Y0;
    wire [10:0] work_roi_y0=HAND_FULL_HEIGHT&&work_hand?0:ROI_Y0;
    wire [10:0] work_roi_y1=HAND_FULL_HEIGHT&&work_hand?HEIGHT-1:ROI_Y1;
    wire [CW:0] work_gh=HAND_FULL_HEIGHT&&work_hand?GH:NORMAL_GH;
    wire roi_y=!ROI_ENABLE||(HAND_FULL_HEIGHT&&capture_hand)||(py>=ROI_Y0&&py<=ROI_Y1);
    wire roi_pixel0=roi_y&&(!ROI_ENABLE||(px>=ROI_X0&&px<=ROI_X1));
    wire roi_pixel1=roi_y&&(!ROI_ENABLE||(px+1>=ROI_X0&&px+1<=ROI_X1));
    wire [10:0] map_x=px>=MAP_X0?px-MAP_X0:0,map_y=py>=capture_y0?py-capture_y0:0;
    wire [10:0] block_x=map_x>>BLOCK_SHIFT;
    wire capture_inside=!COMPACT_ROI||(px>=MAP_X0&&px<=MAP_X1&&py>=capture_y0&&py<=capture_y1);
    wire [AW-1:0] capture_addr=(map_y>>BLOCK_SHIFT)*GW+block_x;
    wire [11:0] gray_threshold=FEATURE_RECOGNITION?config_id[11:0]:DIGIT_THRESHOLD;
    wire [1:0] foreground=capture_hand ? hand_skin : ENABLE_EXTENDED&&digit_mode ? {grayx2[15:8]<gray_threshold,grayx2[7:0]<gray_threshold} : edges;
    wire capture_we=in_de&&capture_inside&&((px+2>MAP_X1)||((map_x&(BLOCK-1))==BLOCK-2))&&
                    ((py==capture_y1)||((map_y&(BLOCK-1))==BLOCK-1));
    // Fixed block support in HANDS only: isolated skin pixels cannot seed a cell.
    // Saturating at the fixed minimum uses 3 bits/column for the default 4 votes.
    localparam integer HAND_COUNT_BITS=HAND_MIN_BLOCK_PIXELS<2?1:$clog2(HAND_MIN_BLOCK_PIXELS+1);
    wire [HAND_COUNT_BITS:0] hand_votes;
    wire [1:0] hand_pair_votes={1'b0,(foreground[0]&&roi_pixel0)}+{1'b0,(foreground[1]&&roi_pixel1)};
    generate if(HAND_RECOGNITION)begin: g_hand_support
        reg [HAND_COUNT_BITS-1:0] support[0:GW-1];integer column_index;
        assign hand_votes={1'b0,support[block_x]}+hand_pair_votes;
        always @(posedge clk or negedge rst_n)begin
            if(!rst_n)begin for(column_index=0;column_index<GW;column_index=column_index+1)support[column_index]<=0;end
            else if(in_vs&&!vs_d)begin for(column_index=0;column_index<GW;column_index=column_index+1)support[column_index]<=0;end
            else if(in_de&&capture_inside&&capture_hand)begin
                if(capture_we)support[block_x]<=0;
                else support[block_x]<=hand_votes>=HAND_MIN_BLOCK_PIXELS?HAND_MIN_BLOCK_PIXELS:hand_votes[HAND_COUNT_BITS-1:0];
            end
        end
    end else begin: g_no_hand_support assign hand_votes=0;end endgenerate
    wire capture_bit=capture_hand ? hand_votes>=HAND_MIN_BLOCK_PIXELS :
        columns[block_x]|(foreground[0]&&roi_pixel0)|(foreground[1]&&roi_pixel1);
    reg map0[0:CELLS-1],map1[0:CELLS-1];
    reg [4:0] labels[0:CELLS-1];
    reg [QW-1:0] queue[0:CELLS-1];
    reg [AW-1:0] read_addr,queue_addr;
    wire [AW-1:0] hand_read_address;
    wire [AW-1:0] label_read_address=work_hand&&(state==DIGIT_START||state==DIGIT_MATCH)?hand_read_address:read_addr;
    reg m0q,m1q;
    reg [4:0] label_q;
    reg [QW-1:0] queue_q;
    always @(posedge clk) begin
        if(capture_we) begin
            if(capture_bank) map1[capture_addr]<=capture_bit;
            else map0[capture_addr]<=capture_bit;
        end
        m0q<=map0[read_addr];m1q<=map1[read_addr];label_q<=labels[label_read_address];queue_q<=queue[queue_addr];
    end
    // Digits/shapes retain their compact center map; ignore stale extra HANDS rows.
    wire map_q=(processing_bank ? m1q : m0q)&&(!HAND_FULL_HEIGHT||work_hand||read_addr<GW*NORMAL_GH);
    wire [2*CW-1:0] queue_coords=queue_q;
    wire [CW-1:0] queue_x=HAND_FULL_HEIGHT?queue_q%GW:queue_coords[CW-1:0];
    wire [CW-1:0] queue_y=HAND_FULL_HEIGHT?queue_q/GW:queue_coords[2*CW-1:CW];
    reg [AW-1:0] clear_index,scan_index;
    reg [CW-1:0] scan_x,scan_y,current_x,current_y,min_x,max_x,min_y,max_y;
    reg [CW-1:0] best_x0,best_x1,best_y0,best_y1;
    reg [AW:0] head,tail,count,best_count;
    reg [4:0] component,best_component;
    reg [1:0] candidates;
    reg limit_error;
    reg [2:0] neighbor;
    reg [31:0] cycles;
    reg [15:0] ring_count,rect_count,corner_count,left_count,right_count,top_count,bottom_count;
    reg [CW:0] nx,ny;
    reg neighbor_ok;
    always @(*) begin
        nx={1'b0,current_x};ny={1'b0,current_y};neighbor_ok=1;
        case(neighbor)
            0:begin nx=current_x-1'b1;ny=current_y-1'b1;neighbor_ok=current_x>0&&current_y>0;end
            1:begin ny=current_y-1'b1;neighbor_ok=current_y>0;end
            2:begin nx=current_x+1'b1;ny=current_y-1'b1;neighbor_ok=current_x+1<GW&&current_y>0;end
            3:begin nx=current_x-1'b1;neighbor_ok=current_x>0;end
            4:begin nx=current_x+1'b1;neighbor_ok=current_x+1<GW;end
            5:begin nx=current_x-1'b1;ny=current_y+1'b1;neighbor_ok=current_x>0&&current_y+1<work_gh;end
            6:begin ny=current_y+1'b1;neighbor_ok=current_y+1<work_gh;end
            default:begin nx=current_x+1'b1;ny=current_y+1'b1;neighbor_ok=current_x+1<GW&&current_y+1<work_gh;end
        endcase
    end
    wire [AW-1:0] neighbor_addr=ny*GW+nx;
    wire seed=state==SCAN_EVAL&&map_q&&label_q==0&&component!=31;
    wire discover=state==NEIGH_EVAL&&map_q&&label_q==0;
    wire label_we=state==CLEAR||seed||discover;
    wire [AW-1:0] label_addr=state==CLEAR ? clear_index : seed ? scan_index : neighbor_addr;
    wire [4:0] label_data=state==CLEAR ? 5'd0 : seed ? component+1'b1 : component;
    wire queue_we=seed||(discover&&tail<CELLS);
    wire [AW-1:0] queue_write=seed ? {AW{1'b0}} : tail[AW-1:0];
    wire [QW-1:0] queue_data=HAND_FULL_HEIGHT?(seed?scan_index:neighbor_addr):
        (seed ? {scan_y,scan_x} : {ny[CW-1:0],nx[CW-1:0]});
    always @(posedge clk) begin
        if(label_we) labels[label_addr]<=label_data;
        if(queue_we) queue[queue_write]<=queue_data;
    end
    wire [CW:0] component_width={1'b0,max_x}-{1'b0,min_x}+1'b1;
    wire [CW:0] component_height={1'b0,max_y}-{1'b0,min_y}+1'b1;
    wire touches_border=ROI_ENABLE&&(COMPACT_ROI ? min_x==0||max_x==GW-1||min_y==0||(!work_hand&&max_y==work_gh-1) :
        min_x<=(ROI_X0>>BLOCK_SHIFT)||max_x>=(ROI_X1>>BLOCK_SHIFT)||min_y<=(ROI_Y0>>BLOCK_SHIFT)||max_y>=(ROI_Y1>>BLOCK_SHIFT));
    wire size_ok=work_hand ? count>=32&&component_height>=8&&component_width>=8&&
        count*100>=component_width*component_height*12&&count*100<=component_width*component_height*90 :
        work_digit_mode&&FEATURE_RECOGNITION ? count>=8&&component_height>=8&&component_width>=1&&component_width*4<=component_height*5 :
        count>=MIN_CELLS&&component_height>=MIN_SIZE&&(work_digit_mode ? component_width>=3&&component_width*4<=component_height*5 :
        component_width>=MIN_SIZE&&count<=((component_width+component_height)<<2));
    wire eligible=size_ok&&!touches_border;
    reg [AW:0] largest_seen;reg [7:0] reject_reason;
    wire [CW:0] width_fit={1'b0,best_x1}-{1'b0,best_x0}+1'b1;
    wire [CW:0] height_fit={1'b0,best_y1}-{1'b0,best_y0}+1'b1;
    wire near_x=scan_x<=best_x0+1'b1||scan_x+1'b1>=best_x1;
    wire near_y=scan_y<=best_y0+1'b1||scan_y+1'b1>=best_y1;
    wire [CW+1:0] xsum={2'd0,best_x0}+best_x1,ysum={2'd0,best_y0}+best_y1;
    wire [CW+1:0] xdouble={1'b0,scan_x,1'b0},ydouble={1'b0,scan_y,1'b0};
    wire [CW+1:0] dx=xdouble>=xsum ? xdouble-xsum : xsum-xdouble;
    wire [CW+1:0] dy=ydouble>=ysum ? ydouble-ysum : ysum-ydouble;
    wire [CW+2:0] octagon=dx>=dy ? {1'b0,dx}+(dy>>1) : {1'b0,dy}+(dx>>1);
    wire [CW+2:0] radius=({2'd0,width_fit}+height_fit-2)>>1;
    wire in_ring=(octagon*8>=radius*7)&&(octagon*4<=radius*5);
    wire rectangle=rect_count*100>=best_count*85&&corner_count>=4&&
        left_count*2>=height_fit&&right_count*2>=height_fit&&top_count*2>=width_fit&&bottom_count*2>=width_fit;
    wire circle=width_fit*4>=height_fit*3&&height_fit*4>=width_fit*3&&
        ring_count*100>=best_count*85&&corner_count==0;
    reg [(HAND_RECOGNITION?1024:128)-1:0] digit_signature;
    reg [(HAND_RECOGNITION?10:7)-1:0] norm_index;
    reg [CW+5:0] norm_x_acc,norm_y_acc,aspect_remainder;
    reg [3:0] norm_aspect;
    reg digit_accepted;
    reg [3:0] matched_digit;
    reg [7:0] digit_distance,digit_margin;
    wire digit_done,digit_accept,hand_done,hand_accept;
    wire [3:0] digit_number,hand_number;
    wire [7:0] digit_dist,digit_runner,hand_dist,hand_runner;
    wire [3:0] hand_raw;
    wire matcher_done=work_hand?hand_done:digit_done,matcher_accepted=work_hand?hand_accept:digit_accept;
    wire [3:0] matcher_digit=work_hand?hand_number:digit_number;
    wire [7:0] matcher_distance=work_hand?hand_dist:digit_dist,matcher_runner=work_hand?hand_runner:digit_runner;
    generate if(ENABLE_EXTENDED&&FEATURE_RECOGNITION)begin: g_features
        digit_feature_match matcher(.clk(clk),.rst_n(rst_n),.start(state==DIGIT_START&&!work_hand),
            .signature(digit_signature[127:0]),.aspect(norm_aspect),.busy(),.done(digit_done),.accepted(digit_accept),
            .digit(digit_number),.distance(digit_dist),.runner_up(digit_runner));
    end else if(ENABLE_EXTENDED)begin: g_digit
        digit_template_match matcher(.clk(clk),.rst_n(rst_n),.start(state==DIGIT_START),
            .signature(digit_signature[127:0]),.aspect(norm_aspect),.busy(),.done(digit_done),.accepted(digit_accept),
            .digit(digit_number),.distance(digit_dist),.runner_up(digit_runner));
    end else begin: g_no_digit
        assign digit_done=0;assign digit_accept=0;assign digit_number=0;assign digit_dist=255;assign digit_runner=255;
    end endgenerate
    generate if(HAND_RECOGNITION)begin: g_hand
        localparam integer CGW=(GW+1)/2;
        // Same completed frame, native mask flag + luminance at16px centers.
        reg [8:0] gray0[0:4095],gray1[0:4095];
        reg [8:0] gray0q,gray1q;
        wire [11:0] gray_address;
        wire gray_we=in_de&&capture_hand&&capture_inside&&roi_pixel0&&
            (map_x[3:0]==8)&&((py[3:0]==8)||((HEIGHT%16<=8)&&py==HEIGHT-1));
        wire [11:0] gray_write=(py>>4)*CGW+(map_x>>4);
        always @(posedge clk)begin
            if(gray_we)begin if(capture_bank)gray1[gray_write]<={hand_skin[0],grayx2[7:0]};else gray0[gray_write]<={hand_skin[0],grayx2[7:0]};end
            gray0q<=gray0[gray_address];gray1q<=gray1[gray_address];
        end
        hand_cnn_match #(.MAP_W(GW),.MAP_H(GH)) matcher(.clk(clk),.rst_n(rst_n),.start(state==DIGIT_START&&work_hand),
            .x0(best_x0),.y0(best_y0),.x1(best_x1),.y1(best_y1),
            .mask_address(hand_read_address),.mask_q(label_q==best_component),.gray_address(gray_address),.gray_q(processing_bank?gray1q:gray0q),.done(hand_done),.accepted(hand_accept),
            .digit(hand_number),.distance(hand_dist),.runner_up(hand_runner),.raw_class(hand_raw));
    end else begin: g_no_hand
        assign hand_done=0;assign hand_accept=0;assign hand_number=0;assign hand_dist=255;assign hand_runner=255;assign hand_raw=0;assign hand_read_address=0;
    end endgenerate
    reg [1:0] geometry_pass;
    wire [CW-1:0] geo_ax,geo_ay,geo_bx,geo_by,geo_cx,geo_cy;wire geo_accepted;wire [7:0] geo_error;
    wire [15:0] geo_count=best_count;
    generate if(FEATURE_RECOGNITION)begin: g_geometry
        triangle_features #(.CW(CW)) geometry(.clk(clk),.rst_n(rst_n),.start(state==FEATURE_INIT),
            .point_valid(state==FEATURE_EVAL&&label_q==best_component),.pass(geometry_pass),.x(scan_x),.y(scan_y),
            .origin_x(best_x0),.origin_y(best_y0),.count(geo_count),.ax(geo_ax),.ay(geo_ay),.bx(geo_bx),.by(geo_by),.cx(geo_cx),.cy(geo_cy),
            .accepted(geo_accepted),.error_score(geo_error));
    end else begin: g_no_geometry
        assign geo_ax=0;assign geo_ay=0;assign geo_bx=0;assign geo_by=0;assign geo_cx=0;assign geo_cy=0;assign geo_accepted=0;assign geo_error=255;
    end endgenerate
    // Three-side tests in bbox coordinates, for 4 axial apex and 4 right-triangle orientations.
    wire [CW:0] local_x={1'b0,scan_x}-{1'b0,best_x0},local_y={1'b0,scan_y}-{1'b0,best_y0};
    wire [CW:0] span_x=width_fit-1'b1,span_y=height_fit-1'b1;
    wire signed [20:0] hu=local_x*span_y,wv=local_y*span_x,area=span_x*span_y;
    wire [20:0] tolerance=(span_x+span_y)<<1;
    function close_line;
        input signed [20:0] delta;input [20:0] tol;
        begin close_line=(delta<0 ? -delta : delta)<=tol;end
    endfunction
    wire left_edge=local_x<=1,right_edge=local_x+1>=span_x;
    wire top_edge=local_y<=1,bottom_edge=local_y+1>=span_y;
    wire tl=left_edge&&top_edge,tr=right_edge&&top_edge,bl=left_edge&&bottom_edge,br=right_edge&&bottom_edge;
    wire tm=top_edge&&close_line((local_x<<1)-$signed({1'b0,span_x}),3);
    wire bm=bottom_edge&&close_line((local_x<<1)-$signed({1'b0,span_x}),3);
    wire lm=left_edge&&close_line((local_y<<1)-$signed({1'b0,span_y}),3);
    wire rm=right_edge&&close_line((local_y<<1)-$signed({1'b0,span_y}),3);
    wire [7:0] triangle_near;
    assign triangle_near[0]=bottom_edge||close_line((hu<<1)+wv-area,tolerance)||close_line((hu<<1)-wv-area,tolerance);
    assign triangle_near[1]=top_edge||close_line((hu<<1)-wv,tolerance)||close_line((hu<<1)+wv-(area<<1),tolerance);
    assign triangle_near[2]=right_edge||close_line((wv<<1)+hu-area,tolerance)||close_line((wv<<1)-hu-area,tolerance);
    assign triangle_near[3]=left_edge||close_line((wv<<1)-hu,tolerance)||close_line((wv<<1)+hu-(area<<1),tolerance);
    assign triangle_near[4]=left_edge||top_edge||close_line(hu+wv-area,tolerance);
    assign triangle_near[5]=right_edge||top_edge||close_line(hu-wv,tolerance);
    assign triangle_near[6]=left_edge||bottom_edge||close_line(hu-wv,tolerance);
    assign triangle_near[7]=right_edge||bottom_edge||close_line(hu+wv-area,tolerance);
    wire [2:0] vertex_bits[0:7];
    assign vertex_bits[0]={tm,bl,br};assign vertex_bits[1]={bm,tl,tr};
    assign vertex_bits[2]={lm,tr,br};assign vertex_bits[3]={rm,tl,bl};
    assign vertex_bits[4]={tl,tr,bl};assign vertex_bits[5]={tl,tr,br};
    assign vertex_bits[6]={tl,bl,br};assign vertex_bits[7]={tr,bl,br};
    reg [15:0] triangle_count[0:7];reg [2:0] triangle_vertices[0:7];
    reg triangle;reg [2:0] triangle_orientation;reg [15:0] triangle_best;
    integer ti,tj;
    always @* begin
        triangle=0;triangle_orientation=0;triangle_best=0;
        for(tj=0;tj<8;tj=tj+1)if(ENABLE_EXTENDED&&!FEATURE_RECOGNITION&&triangle_vertices[tj]==7&&triangle_count[tj]*100>=best_count*85&&triangle_count[tj]>triangle_best)begin
            triangle=1;triangle_orientation=tj;triangle_best=triangle_count[tj];
        end
        if(FEATURE_RECOGNITION)begin triangle=geo_accepted;triangle_orientation=7;end
    end
    wire [3:0] classification=limit_error||candidates>1 ? 4'd3 : candidates==0 ? 4'd0 :
        work_digit_mode ? (digit_accepted ? 4'd5+matched_digit : 4'd0) : rectangle ? 4'd2 : circle ? 4'd1 : triangle ? 4'd4 : 4'd0;
    task advance_scan;
        begin
            if(scan_index==CELLS-1) state<=FEATURE_INIT;
            else begin
                scan_index<=scan_index+1'b1;
                if(scan_x==GW-1) begin scan_x<=0;scan_y<=scan_y+1'b1;end else scan_x<=scan_x+1'b1;
                state<=SCAN_REQ;
            end
        end
    endtask
    task advance_neighbor;
        begin
            if(neighbor==7) state<=POP_REQ;
            else begin neighbor<=neighbor+1'b1;state<=NEIGH_REQ;end
        end
    endtask
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            pending_hand<=0;pending_hand_valid<=0;hand_confirmed<=0;pending_hand_frame<=0;pending_hand_config<=0;
            capture_bank<=0;processing_bank<=1;vs_d<=0;de_d<=0;px<=0;py<=0;pair_count<=0;columns<=0;
            capture_frame<=0;capture_config<=0;capture_valid<=0;work_frame<=0;work_config<=0;sample_timer<=SAMPLE_INTERVAL_CYCLES;
            capture_digit_mode<=0;work_digit_mode<=0;digit_signature<=0;norm_index<=0;norm_x_acc<=0;norm_y_acc<=0;aspect_remainder<=0;norm_aspect<=0;
            digit_accepted<=0;matched_digit<=0;digit_distance<=255;digit_margin<=0;
            result_score<=255;result_margin<=0;result_orientation<=0;result_cells<=0;result_components<=0;result_candidates<=0;
            result_reason<=0;vertex_ax<=0;vertex_ay<=0;vertex_bx<=0;vertex_by<=0;vertex_cx<=0;vertex_cy<=0;geometry_pass<=0;largest_seen<=0;reject_reason<=1;
            for(ti=0;ti<8;ti=ti+1)begin triangle_count[ti]<=0;triangle_vertices[ti]<=0;end
            state<=IDLE;read_addr<=0;queue_addr<=0;clear_index<=0;scan_index<=0;scan_x<=0;scan_y<=0;
            current_x<=0;current_y<=0;min_x<=0;max_x<=0;min_y<=0;max_y<=0;count<=0;head<=0;tail<=0;
            best_x0<=0;best_x1<=0;best_y0<=0;best_y1<=0;best_count<=0;component<=0;best_component<=0;
            candidates<=0;limit_error<=0;neighbor<=0;cycles<=0;analysis_cycles<=0;dropped_maps<=0;
            result_valid<=0;result_class<=0;result_frame<=0;result_config<=0;box_x0<=0;box_y0<=0;box_x1<=0;box_y1<=0;
            ring_count<=0;rect_count<=0;corner_count<=0;left_count<=0;right_count<=0;top_count<=0;bottom_count<=0;
        end else begin
            vs_d<=in_vs;de_d<=in_de;
            if(SAMPLE_INTERVAL_CYCLES!=0&&sample_timer<SAMPLE_INTERVAL_CYCLES) sample_timer<=sample_timer+1'b1;
            if(in_de) begin
                px<=px+2;pair_count<=pair_count+1'b1;
                if(px==0&&py==0) begin capture_frame<=source_id;capture_config<=config_id;capture_valid<=source_valid;capture_digit_mode<=ENABLE_EXTENDED&&digit_mode;end
                else if(!source_valid||(ENABLE_EXTENDED&&digit_mode!=capture_digit_mode)||
                    (HAND_RECOGNITION&&(source_id!=capture_frame||config_id!=capture_config))) capture_valid<=0;
                if(capture_inside)begin
                    if(capture_we) columns[block_x]<=0;
                    else columns[block_x]<=capture_bit;
                end
            end else px<=0;
            if(de_d&&!in_de) py<=py+1'b1;
            if(in_vs&&!vs_d) begin
                px<=0;py<=0;pair_count<=0;columns<=0;capture_valid<=0;
                if(pair_count==WIDTH*HEIGHT/2&&capture_valid&&sample_due) begin
                    if(state==IDLE) begin
                        sample_timer<=0;
                        processing_bank<=capture_bank;capture_bank<=~capture_bank;
                        work_frame<=capture_frame;work_config<=capture_config;work_digit_mode<=capture_digit_mode;digit_accepted<=0;digit_distance<=255;digit_margin<=0;
                        clear_index<=0;scan_index<=0;scan_x<=0;scan_y<=0;
                        component<=0;candidates<=0;best_count<=0;best_component<=0;limit_error<=0;cycles<=0;largest_seen<=0;reject_reason<=1;
                        state<=CLEAR;
                    end else dropped_maps<=dropped_maps+1'b1;
                end
            end
            if(state!=IDLE) cycles<=cycles+1'b1;
            case(state)
                IDLE:;
                CLEAR:if(clear_index==CELLS-1) state<=SCAN_REQ;else clear_index<=clear_index+1'b1;
                SCAN_REQ:begin read_addr<=scan_index;state<=SCAN_WAIT;end
                SCAN_WAIT:state<=SCAN_EVAL;
                SCAN_EVAL:begin
                    if(map_q&&label_q==0) begin
                        if(component==31) begin limit_error<=1;state<=DONE;end
                        else begin
                            component<=component+1'b1;head<=0;tail<=1;count<=0;
                            min_x<=scan_x;max_x<=scan_x;min_y<=scan_y;max_y<=scan_y;state<=POP_REQ;
                        end
                    end else advance_scan();
                end
                POP_REQ:begin
                    if(head<tail) begin queue_addr<=head[AW-1:0];state<=POP_WAIT;end
                    else begin
                        if(count>largest_seen)begin largest_seen<=count;reject_reason<=touches_border?3:!size_ok?2:0;end
                        if(eligible) begin
                            if(candidates<2) candidates<=candidates+1'b1;
                            if(count>best_count) begin
                                best_count<=count;best_component<=component;
                                best_x0<=min_x;best_x1<=max_x;best_y0<=min_y;best_y1<=max_y;
                            end
                        end
                        advance_scan();
                    end
                end
                POP_WAIT:state<=POP_EVAL;
                POP_EVAL:begin
                    current_x<=queue_x;current_y<=queue_y;head<=head+1'b1;count<=count+1'b1;
                    if(queue_x<min_x) min_x<=queue_x;
                    if(queue_x>max_x) max_x<=queue_x;
                    if(queue_y<min_y) min_y<=queue_y;
                    if(queue_y>max_y) max_y<=queue_y;
                    neighbor<=0;state<=NEIGH_REQ;
                end
                NEIGH_REQ:if(neighbor_ok) begin read_addr<=neighbor_addr;state<=NEIGH_WAIT;end else advance_neighbor();
                NEIGH_WAIT:state<=NEIGH_EVAL;
                NEIGH_EVAL:begin
                    if(discover) begin
                        if(tail<CELLS) tail<=tail+1'b1;else limit_error<=1;
                    end
                    advance_neighbor();
                end
                FEATURE_INIT:begin
                    if(candidates!=1||limit_error) state<=DONE;
                    else if(work_hand)state<=DIGIT_START;
                    else if(work_digit_mode)begin
                        digit_signature<=0;norm_index<=0;norm_x_acc<=width_fit;norm_y_acc<=height_fit;
                        norm_aspect<=0;aspect_remainder<=width_fit<<3;state<=DIGIT_REQ;
                    end else begin
                        scan_index<=0;scan_x<=0;scan_y<=0;geometry_pass<=0;
                        for(ti=0;ti<8;ti=ti+1)begin triangle_count[ti]<=0;triangle_vertices[ti]<=0;end
                        ring_count<=0;rect_count<=0;corner_count<=0;left_count<=0;right_count<=0;top_count<=0;bottom_count<=0;
                        state<=FEATURE_REQ;
                    end
                end
                FEATURE_REQ:begin read_addr<=scan_index;state<=FEATURE_WAIT;end
                FEATURE_WAIT:state<=FEATURE_EVAL;
                FEATURE_EVAL:begin
                    if(label_q==best_component) begin
                        if(ENABLE_EXTENDED&&!FEATURE_RECOGNITION)for(ti=0;ti<8;ti=ti+1)begin
                            if(triangle_near[ti])triangle_count[ti]<=triangle_count[ti]+1'b1;
                            triangle_vertices[ti]<=triangle_vertices[ti]|vertex_bits[ti];
                        end
                        if(!FEATURE_RECOGNITION||geometry_pass==0)begin
                        if(in_ring) ring_count<=ring_count+1'b1;
                        if(near_x||near_y) rect_count<=rect_count+1'b1;
                        if(near_x&&near_y) corner_count<=corner_count+1'b1;
                        if(scan_x<=best_x0+1'b1) left_count<=left_count+1'b1;
                        if(scan_x+1'b1>=best_x1) right_count<=right_count+1'b1;
                        if(scan_y<=best_y0+1'b1) top_count<=top_count+1'b1;
                        if(scan_y+1'b1>=best_y1) bottom_count<=bottom_count+1'b1;
                        end
                    end
                    if(scan_index==CELLS-1)begin
                        if(FEATURE_RECOGNITION&&geometry_pass!=3)begin geometry_pass<=geometry_pass+1'b1;scan_index<=0;scan_x<=0;scan_y<=0;state<=FEATURE_REQ;end
                        else state<=DONE;
                    end else begin
                        scan_index<=scan_index+1'b1;
                        if(scan_x==GW-1) begin scan_x<=0;scan_y<=scan_y+1'b1;end else scan_x<=scan_x+1'b1;
                        state<=FEATURE_REQ;
                    end
                end
                DIGIT_REQ:begin
                    read_addr<=(best_y0+(work_hand?(norm_y_acc>>6):(norm_y_acc>>5)))*GW+
                        best_x0+(work_hand?(norm_x_acc>>6):(norm_x_acc>>4));state<=DIGIT_WAIT;
                end
                DIGIT_WAIT:state<=DIGIT_EVAL;
                DIGIT_EVAL:begin
                    digit_signature[norm_index]<=label_q==best_component;
                    if(norm_index==(work_hand?1023:127))state<=DIGIT_ASPECT;
                    else begin
                        norm_index<=norm_index+1'b1;
                        if(work_hand?(norm_index[4:0]==31):(norm_index[2:0]==7))begin norm_x_acc<=width_fit;norm_y_acc<=norm_y_acc+(height_fit<<1);end
                        else norm_x_acc<=norm_x_acc+(width_fit<<1);
                        state<=DIGIT_REQ;
                    end
                end
                DIGIT_ASPECT:if(aspect_remainder>=height_fit&&norm_aspect!=15)begin
                    aspect_remainder<=aspect_remainder-height_fit;norm_aspect<=norm_aspect+1'b1;
                end else state<=DIGIT_START;
                DIGIT_START:state<=DIGIT_MATCH;
                DIGIT_MATCH:if(matcher_done)begin
                    digit_accepted<=matcher_accepted;matched_digit<=matcher_digit;digit_distance<=matcher_distance;
                    digit_margin<=work_hand?hand_runner:matcher_runner-matcher_distance;state<=DONE;
                end
                DONE:begin
                    result_valid<=1;result_frame<=work_frame;result_config<=work_config;analysis_cycles<=cycles;
                    result_class<=classification;result_cells<=best_count;result_components<=component;result_candidates<=candidates;
                    result_score<=work_hand ? (candidates==1&&!limit_error?{4'd0,hand_raw}:8'hff) : work_digit_mode&&candidates==1&&!limit_error ? digit_distance : classification==4 ? (FEATURE_RECOGNITION?geo_error:(best_count-triangle_best>255 ? 255 : best_count-triangle_best)) : 255;
                    result_margin<=work_digit_mode ? digit_margin : 0;result_orientation<=classification==4 ? triangle_orientation : 0;
                    result_reason<=limit_error?5:candidates>1?4:candidates==0?reject_reason:classification==0?(work_hand?(hand_raw==0?6:9):work_digit_mode?(digit_distance>32?6:7):8):0;
                    if(work_hand)begin
                        if(classification>=5&&classification<=14)begin
                            pending_hand<=classification;pending_hand_valid<=1;
                            pending_hand_frame<=work_frame;pending_hand_config<=work_config;
                            if(pending_hand_valid&&pending_hand==classification&&pending_hand_config==work_config&&
                                ((hand_confirmed&&pending_hand_frame==work_frame)||
                                (pending_hand_frame!=work_frame&&work_frame-pending_hand_frame<=60)))hand_confirmed<=1;
                            else begin hand_confirmed<=0;result_class<=0;result_reason<=10;end
                        end else begin pending_hand_valid<=0;hand_confirmed<=0;end
                    end else begin pending_hand_valid<=0;hand_confirmed<=0;end
                    vertex_ax<=classification==4&&FEATURE_RECOGNITION?MAP_X0+(geo_ax<<BLOCK_SHIFT)+(BLOCK>>1):0;
                    vertex_ay<=classification==4&&FEATURE_RECOGNITION?work_y0+(geo_ay<<BLOCK_SHIFT)+(BLOCK>>1):0;
                    vertex_bx<=classification==4&&FEATURE_RECOGNITION?MAP_X0+(geo_bx<<BLOCK_SHIFT)+(BLOCK>>1):0;
                    vertex_by<=classification==4&&FEATURE_RECOGNITION?work_y0+(geo_by<<BLOCK_SHIFT)+(BLOCK>>1):0;
                    vertex_cx<=classification==4&&FEATURE_RECOGNITION?MAP_X0+(geo_cx<<BLOCK_SHIFT)+(BLOCK>>1):0;
                    vertex_cy<=classification==4&&FEATURE_RECOGNITION?work_y0+(geo_cy<<BLOCK_SHIFT)+(BLOCK>>1):0;
                    if(FEATURE_RECOGNITION&&candidates==0)begin box_x0<=0;box_y0<=0;box_x1<=0;box_y1<=0;end
                    else begin
                        box_x0<=ROI_ENABLE&&MAP_X0+(best_x0<<BLOCK_SHIFT)<ROI_X0?ROI_X0:MAP_X0+(best_x0<<BLOCK_SHIFT);
                        box_y0<=ROI_ENABLE&&work_y0+(best_y0<<BLOCK_SHIFT)<work_roi_y0?work_roi_y0:work_y0+(best_y0<<BLOCK_SHIFT);
                        box_x1<=ROI_ENABLE&&MAP_X0+((best_x1+1)<<BLOCK_SHIFT)-1>ROI_X1?ROI_X1:MAP_X0+((best_x1+1)<<BLOCK_SHIFT)-1>=WIDTH?WIDTH-1:MAP_X0+((best_x1+1)<<BLOCK_SHIFT)-1;
                        box_y1<=ROI_ENABLE&&work_y0+((best_y1+1)<<BLOCK_SHIFT)-1>work_roi_y1?work_roi_y1:work_y0+((best_y1+1)<<BLOCK_SHIFT)-1>=HEIGHT?HEIGHT-1:work_y0+((best_y1+1)<<BLOCK_SHIFT)-1;
                    end
                    state<=IDLE;
                end
                default:state<=IDLE;
            endcase
        end
    end
endmodule
