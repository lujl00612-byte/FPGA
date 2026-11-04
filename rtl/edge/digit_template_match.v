// Fixed 8x16 template matcher. Distance=Hamming+2*aspect difference.
// Sixteen fixed exemplars/class; runner-up is from another digit class.
module digit_template_match #(
    parameter MEMFILE="rtl/edge/printed_digit_templates.mem",
    parameter integer MAX_DISTANCE=32,MIN_MARGIN=4
)(
    input wire clk,rst_n,start,
    input wire [127:0] signature,
    input wire [3:0] aspect,
    output reg busy,done,accepted,
    output reg [3:0] digit,
    output reg [7:0] distance,runner_up
);
    reg [131:0] rom[0:159];
    initial $readmemh(MEMFILE,rom);
    reg [3:0] class_index,variant;
    wire [7:0] address={class_index,variant};
    reg [131:0] rom_q;
    always @(posedge clk) rom_q<=rom[address];
    reg [127:0] saved_signature,difference;
    reg [3:0] saved_aspect;
    reg [6:0] bit_index;
    reg [7:0] current_score,class_min,best,second;
    reg [3:0] best_digit;
    reg [2:0] state;
    localparam IDLE=0,FETCH=1,LOAD=2,COUNT=3,FINISH=4;
    wire [7:0] total=current_score+{7'd0,difference[0]};
    wire [7:0] class_score=total<class_min ? total : class_min;
    wire [4:0] aspect_delta=saved_aspect>=rom_q[131:128] ? saved_aspect-rom_q[131:128] : rom_q[131:128]-saved_aspect;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            class_index<=0;variant<=0;saved_signature<=0;difference<=0;saved_aspect<=0;bit_index<=0;
            current_score<=0;class_min<=255;best<=255;second<=255;best_digit<=0;state<=IDLE;
            busy<=0;done<=0;accepted<=0;digit<=0;distance<=255;runner_up<=255;
        end else begin
            done<=0;
            case(state)
                IDLE:if(start)begin
                    saved_signature<=signature;saved_aspect<=aspect;class_index<=0;variant<=0;
                    class_min<=255;best<=255;second<=255;best_digit<=0;accepted<=0;busy<=1;state<=FETCH;
                end
                FETCH:state<=LOAD;
                LOAD:begin difference<=saved_signature^rom_q[127:0];current_score<={2'd0,aspect_delta,1'b0};bit_index<=0;state<=COUNT;end
                COUNT:begin
                    difference<=difference>>1;current_score<=total;bit_index<=bit_index+1'b1;
                    if(bit_index==127)begin
                        if(variant==15)begin
                            if(class_score<best)begin second<=best;best<=class_score;best_digit<=class_index;end
                            else if(class_score<second)second<=class_score;
                            class_min<=255;variant<=0;class_index<=class_index+1'b1;
                            state<=class_index==9 ? FINISH : FETCH;
                        end else begin class_min<=class_score;variant<=variant+1'b1;state<=FETCH;end
                    end
                end
                FINISH:begin
                    digit<=best_digit;distance<=best;runner_up<=second;
                    accepted<=best<=MAX_DISTANCE&&{1'b0,second}>={1'b0,best}+MIN_MARGIN;
                    done<=1;busy<=0;state<=IDLE;
                end
                default:state<=IDLE;
            endcase
        end
    end
endmodule
