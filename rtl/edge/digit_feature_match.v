// Fixed 4x8 zoning features: each bin is foreground count in a 2x2 cell
// of the normalized 8x16 mask. L1 feature distance + 2*aspect difference.
module digit_feature_match #(
    parameter MEMFILE="rtl/edge/digit_features_v14.mem",
    parameter integer MAX_DISTANCE=32,MIN_MARGIN=4
)(input wire clk,rst_n,start,input wire [127:0] signature,input wire [3:0] aspect,
    output reg busy,done,accepted,output reg [3:0] digit,output reg [7:0] distance,runner_up);
    reg [99:0] rom[0:319];initial $readmemh(MEMFILE,rom);
    reg [3:0] class_index,best_digit;reg [4:0] variant,bin_index;
    wire [8:0] address={class_index,variant};reg [99:0] rom_q;
    always @(posedge clk)rom_q<=rom[address];
    reg [95:0] features,query_shift,template_shift;
    reg [3:0] saved_aspect;reg [7:0] current_score,class_min,best,second;
    reg [2:0] state;integer row,col;
    wire [2:0] a=query_shift[2:0],b=template_shift[2:0];
    wire [7:0] total=current_score+(a>=b?a-b:b-a);
    wire [7:0] class_score=total<class_min?total:class_min;
    wire [4:0] aspect_delta=saved_aspect>=rom_q[99:96]?saved_aspect-rom_q[99:96]:rom_q[99:96]-saved_aspect;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            class_index<=0;best_digit<=0;variant<=0;bin_index<=0;features<=0;query_shift<=0;template_shift<=0;saved_aspect<=0;
            current_score<=0;class_min<=255;best<=255;second<=255;state<=0;busy<=0;done<=0;accepted<=0;digit<=0;distance<=255;runner_up<=255;
        end else begin
            done<=0;
            case(state)
                0:if(start)begin
                    for(row=0;row<8;row=row+1)for(col=0;col<4;col=col+1)
                        features[(row*4+col)*3+:3]<={2'd0,signature[row*16+col*2]}+{2'd0,signature[row*16+col*2+1]}+
                            {2'd0,signature[row*16+8+col*2]}+{2'd0,signature[row*16+8+col*2+1]};
                    saved_aspect<=aspect;class_index<=0;variant<=0;class_min<=255;best<=255;second<=255;accepted<=0;busy<=1;state<=1;
                end
                1:state<=2;
                2:begin query_shift<=features;template_shift<=rom_q[95:0];current_score<={2'd0,aspect_delta,1'b0};bin_index<=0;state<=3;end
                3:begin
                    query_shift<=query_shift>>3;template_shift<=template_shift>>3;current_score<=total;bin_index<=bin_index+1'b1;
                    if(bin_index==31)begin
                        if(variant==31)begin
                            if(class_score<best)begin second<=best;best<=class_score;best_digit<=class_index;end
                            else if(class_score<second)second<=class_score;
                            class_min<=255;variant<=0;class_index<=class_index+1'b1;state<=class_index==9?4:1;
                        end else begin class_min<=class_score;variant<=variant+1'b1;state<=1;end
                    end
                end
                4:begin digit<=best_digit;distance<=best;runner_up<=second;accepted<=best<=MAX_DISTANCE&&{1'b0,second}>={1'b0,best}+MIN_MARGIN;done<=1;busy<=0;state<=0;end
                default:state<=0;
            endcase
        end
    end
endmodule
