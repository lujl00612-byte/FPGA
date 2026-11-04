// Sequential signed INT8 CNN; one MAC, synchronous ROM/RAM, fixed int16 scores.
// Model: 2x32x32 ->16x16x16 ->24x8x8 ->32x4x4 ->11 (CHW flatten).
module hand_cnn_core(
    input wire clk,rst_n,start,load_we,
    input wire [10:0] load_addr,probe_addr,
    input wire [7:0] load_data,
    output wire [7:0] probe_data,
    output wire busy,
    output reg done,accepted,
    output reg [3:0] digit,
    output reg [7:0] distance,runner_up,
    output reg [3:0] raw_class
);
    localparam IDLE=0,BIAS_REQ=1,BIAS_WAIT=2,BIAS_LOAD=3,MAC_REQ=4,MAC_WAIT=5,MAC_ADD=6,WRITE=7,FINISH=8;
    reg [3:0] state;
    assign busy=state!=IDLE;
    reg [1:0] layer;
    reg [4:0] oc,ox,oy;
    reg [8:0] ic;
    reg [1:0] kx,ky;
    reg [8:0] term;
    reg [13:0] channel_weight_base,waddr;
    reg [6:0] parameter_base,paddr;
    reg [10:0] raddr0;
    reg [11:0] raddr1;
    reg signed [7:0] wq,m0q,m1q;
    reg signed [31:0] bq,acc;
    reg signed [7:0] sq,shift;
    reg pad;
    reg signed [15:0] logits[0:10];
    reg signed [15:0] best_score,second_score;
    reg [3:0] best_class;
    reg [7:0] mem0[0:2047],mem1[0:4095];
    reg signed [7:0] weights[0:16383];
    // One shared address: pack signed bias and signed shift into one 40-bit ROM.
    reg [39:0] parameters[0:127];
    initial begin
        $readmemh("rtl/edge/cnn/weights.mem",weights);
        $readmemh("rtl/edge/cnn/parameters.mem",parameters);
    end
    assign probe_data=m0q;
    wire [4:0] last_xy=layer==0?15:layer==1?7:3;
    wire [8:0] last_ic=layer==0?1:layer==1?15:layer==2?23:511;
    wire [4:0] last_oc=layer==0?15:layer==1?23:layer==2?31:10;
    wire [9:0] terms_per_channel=layer==0?18:layer==1?144:layer==2?216:512;
    wire signed [6:0] iy=$signed({1'b0,oy,1'b0})+$signed({5'd0,ky})-7'sd1;
    wire signed [6:0] ix=$signed({1'b0,ox,1'b0})+$signed({5'd0,kx})-7'sd1;
    wire signed [6:0] input_dim=layer==0?32:layer==1?16:8;
    wire outside=layer!=3&&(ix<0||iy<0||ix>=input_dim||iy>=input_dim);
    reg [11:0] source_address,destination_address;
    always @* begin
        case(layer)
            0:begin source_address=(ic<<10)+(iy<<5)+ix;destination_address=(oc<<8)+(oy<<4)+ox;end
            1:begin source_address=(ic<<8)+(iy<<4)+ix;destination_address=(oc<<6)+(oy<<3)+ox;end
            2:begin source_address=(ic<<6)+(iy<<3)+ix;destination_address=(oc<<4)+(oy<<2)+ox;end
            default:begin source_address=ic;destination_address=0;end
        endcase
        if(outside)source_address=0;
    end
    wire signed [7:0] sample=pad?8'sd0:layer[0]?m1q:m0q;
    wire signed [15:0] product=sample*wq;
    function signed [15:0] quantize;
        input signed [31:0] value;
        input signed [7:0] amount;
        input final_layer;
        reg signed [63:0] magnitude,rounded;
        begin
            magnitude=value<0?-$signed({{32{value[31]}},value}):$signed({{32{value[31]}},value});
            if(amount>0)rounded=(magnitude+(64'sd1<<(amount-1)))>>>amount;
            else rounded=magnitude<<<(-amount);
            if(final_layer)begin
                if(rounded>32767)rounded=32767;
                quantize=value<0?-rounded:rounded;
            end else quantize=value<0?0:rounded>127?127:rounded;
        end
    endfunction
    wire signed [15:0] quantized=quantize(acc,shift,layer==3);
    wire write0=load_we&&!busy||(state==WRITE&&layer==1);
    wire write1=state==WRITE&&(layer==0||layer==2);
    always @(posedge clk)begin
        // Present the current MAC address directly to synchronous memories.
        // The registered result is consumed in MAC_ADD on the following cycle.
        wq<=weights[state==MAC_REQ?channel_weight_base+term:waddr];
        {sq,bq}<=parameters[paddr];
        m0q<=mem0[busy?(state==MAC_REQ?source_address[10:0]:raddr0):probe_addr];
        m1q<=mem1[state==MAC_REQ?source_address:raddr1];
        if(write0)mem0[load_we&&!busy?load_addr:destination_address[10:0]]<=load_we&&!busy?load_data:quantized[7:0];
        if(write1)mem1[destination_address]<=quantized[7:0];
    end
    wire signed [16:0] gap=$signed({best_score[15],best_score})-$signed({second_score[15],second_score});
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            state<=IDLE;layer<=0;oc<=0;ox<=0;oy<=0;ic<=0;kx<=0;ky<=0;term<=0;
            channel_weight_base<=0;parameter_base<=0;waddr<=0;paddr<=0;raddr0<=0;raddr1<=0;
            acc<=0;shift<=0;pad<=0;best_score<=-32768;second_score<=-32768;best_class<=0;
            done<=0;accepted<=0;digit<=0;distance<=255;runner_up<=255;raw_class<=0;
        end else begin
            done<=0;
            case(state)
                IDLE:if(start)begin
                    layer<=0;oc<=0;ox<=0;oy<=0;channel_weight_base<=0;parameter_base<=0;
                    best_score<=-32768;second_score<=-32768;best_class<=0;state<=BIAS_REQ;
                end
                BIAS_REQ:begin paddr<=parameter_base+oc;state<=BIAS_WAIT;end
                BIAS_WAIT:state<=BIAS_LOAD;
                BIAS_LOAD:begin acc<=bq;shift<=sq;ic<=0;kx<=0;ky<=0;term<=0;state<=MAC_REQ;end
                MAC_REQ:begin
                    raddr0<=source_address[10:0];raddr1<=source_address;waddr<=channel_weight_base+term;pad<=outside;state<=MAC_ADD;
                end
                MAC_WAIT:state<=MAC_ADD;
                MAC_ADD:begin
                    acc<=acc+{{16{product[15]}},product};
                    if(layer==3)begin
                        if(ic==511)state<=WRITE;
                        else begin ic<=ic+1'b1;term<=term+1'b1;state<=MAC_REQ;end
                    end else if(kx==2)begin
                        kx<=0;
                        if(ky==2)begin
                            ky<=0;
                            if(ic==last_ic)state<=WRITE;
                            else begin ic<=ic+1'b1;term<=term+1'b1;state<=MAC_REQ;end
                        end else begin ky<=ky+1'b1;term<=term+1'b1;state<=MAC_REQ;end
                    end else begin kx<=kx+1'b1;term<=term+1'b1;state<=MAC_REQ;end
                end
                WRITE:begin
                    if(layer==3)begin
                        logits[oc]<=quantized;
                        if(oc==0||quantized>best_score)begin second_score<=best_score;best_score<=quantized;best_class<=oc;end
                        else if(quantized>second_score)second_score<=quantized;
                        if(oc==10)state<=FINISH;
                        else begin oc<=oc+1'b1;channel_weight_base<=channel_weight_base+terms_per_channel;state<=BIAS_REQ;end
                    end else if(ox==last_xy)begin
                        ox<=0;
                        if(oy==last_xy)begin
                            oy<=0;
                            if(oc==last_oc)begin
                                oc<=0;layer<=layer+1'b1;
                                if(layer==0)begin channel_weight_base<=288;parameter_base<=16;end
                                else if(layer==1)begin channel_weight_base<=3744;parameter_base<=40;end
                                else begin channel_weight_base<=10656;parameter_base<=72;end
                            end else begin oc<=oc+1'b1;channel_weight_base<=channel_weight_base+terms_per_channel;end
                            state<=BIAS_REQ;
                        end else begin oy<=oy+1'b1;state<=BIAS_REQ;end
                    end else begin ox<=ox+1'b1;state<=BIAS_REQ;end
                end
                FINISH:begin
                    accepted<=best_class!=0&&gap>=64;
                    raw_class<=best_class;
                    digit<=best_class==0?0:best_class-1'b1;
                    distance<=best_class!=0&&gap>=64?0:255;
                    runner_up<=gap>255?255:gap[7:0];
                    done<=1;state<=IDLE;
                end
                default:state<=IDLE;
            endcase
        end
    end
endmodule
