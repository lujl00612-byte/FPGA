// TH/FPS, effective stages and exact-Canny status, with one pixel of latency.
module contest_status_osd #(parameter integer DETECTION_OVERLAY=0,CLASS_BITS=2,EXTENDED_RECOGNITION=0,HAND_RECOGNITION=0) (
    input wire i_clk,i_rst_n,i_de,i_hs,i_vs,
    input wire [10:0] i_x,i_y,
    input wire [11:0] i_threshold,
    input wire [7:0] i_fps,
    input wire [1:0] i_mode,
    input wire [2:0] i_exact_status,
    input wire [31:0] i_exact_cycles,
    input wire i_freeze,i_fault,i_shape_ready,
    input wire [1:0] i_view,i_age,
    input wire [CLASS_BITS-1:0] i_shape_class,
    input wire i_digit_mode,
    input wire [7:0] i_shape_reason,
    input wire [7:0] i_hand_raw,
    input wire [2:0] i_history_count,
    input wire [7:0] i_shape_age,
    input wire [31:0] i_frame,
    input wire [7:0] i_r,i_g,i_b,
    output reg o_de,o_hs,o_vs,
    output reg [7:0] o_r,o_g,o_b
);
    wire [7:0] th_r,th_g,th_b;
    threshold_osd u_threshold (
        .i_clk(i_clk),.i_rst_n(i_rst_n),.i_de(i_de),.i_x(i_x),.i_y(i_y),.i_threshold(i_threshold),
        .i_r(i_r),.i_g(i_g),.i_b(i_b),.o_r(th_r),.o_g(th_g),.o_b(th_b));
    reg [7:0] fps_seen,remainder;
    reg [3:0] hundreds,tens,dh,dt,du;
    reg [1:0] state;
    always @(posedge i_clk or negedge i_rst_n) begin
        if(!i_rst_n) begin fps_seen<=255;remainder<=0;hundreds<=0;tens<=0;dh<=0;dt<=0;du<=0;state<=0;end
        else case(state)
            0:if(i_fps!=fps_seen) begin fps_seen<=i_fps;remainder<=i_fps;hundreds<=0;tens<=0;state<=1;end
            1:if(remainder>=100) begin remainder<=remainder-100;hundreds<=hundreds+1'b1;end else state<=2;
            2:if(remainder>=10) begin remainder<=remainder-10;tens<=tens+1'b1;end
              else begin dh<=hundreds;dt<=tens;du<=remainder[3:0];state<=0;end
            default:state<=0;
        endcase
    end
    function [34:0] glyph;
        input [7:0] ch;
        begin
            case(ch)
                "0":glyph=35'b01110_10001_10011_10101_11001_10001_01110;
                "1":glyph=35'b00100_01100_00100_00100_00100_00100_01110;
                "2":glyph=35'b01110_10001_00001_00010_00100_01000_11111;
                "3":glyph=35'b11110_00001_00001_01110_00001_00001_11110;
                "4":glyph=35'b00010_00110_01010_10010_11111_00010_00010;
                "5":glyph=35'b11111_10000_10000_11110_00001_00001_11110;
                "6":glyph=35'b01110_10000_10000_11110_10001_10001_01110;
                "7":glyph=35'b11111_00001_00010_00100_01000_01000_01000;
                "8":glyph=35'b01110_10001_10001_01110_10001_10001_01110;
                "9":glyph=35'b01110_10001_10001_01111_00001_00001_01110;
                "A":glyph=35'b01110_10001_10001_11111_10001_10001_10001;
                "B":glyph=35'b11110_10001_10001_11110_10001_10001_11110;
                "C":glyph=35'b01111_10000_10000_10000_10000_10000_01111;
                "D":glyph=35'b11110_10001_10001_10001_10001_10001_11110;
                "E":glyph=35'b11111_10000_10000_11110_10000_10000_11111;
                "F":glyph=35'b11111_10000_10000_11110_10000_10000_10000;
                "G":glyph=35'b01111_10000_10000_10111_10001_10001_01111;
                "H":glyph=35'b10001_10001_10001_11111_10001_10001_10001;
                "I":glyph=35'b01110_00100_00100_00100_00100_00100_01110;
                "L":glyph=35'b10000_10000_10000_10000_10000_10000_11111;
                "M":glyph=35'b10001_11011_10101_10101_10001_10001_10001;
                "N":glyph=35'b10001_11001_11001_10101_10011_10011_10001;
                "O":glyph=35'b01110_10001_10001_10001_10001_10001_01110;
                "P":glyph=35'b11110_10001_10001_11110_10000_10000_10000;
                "R":glyph=35'b11110_10001_10001_11110_10100_10010_10001;
                "S":glyph=35'b01111_10000_10000_01110_00001_00001_11110;
                "T":glyph=35'b11111_00100_00100_00100_00100_00100_00100;
                "U":glyph=35'b10001_10001_10001_10001_10001_10001_01110;
                "V":glyph=35'b10001_10001_10001_10001_10001_01010_00100;
                "Y":glyph=35'b10001_10001_01010_00100_00100_00100_00100;
                "Z":glyph=35'b11111_00001_00010_00100_01000_10000_11111;
                "W":glyph=35'b10001_10001_10001_10101_10101_11011_10001;
                "X":glyph=35'b10001_10001_01010_00100_01010_10001_10001;
                "K":glyph=35'b10001_10010_10100_11000_10100_10010_10001;
                ".":glyph=35'b00000_00000_00000_00000_00000_00100_00100;
                ":":glyph=35'b00000_00100_00100_00000_00100_00100_00000;
                ">":glyph=35'b10000_01000_00100_00010_00100_01000_10000;
                default:glyph=0;
            endcase
        end
    endfunction
    reg [0:8*32-1] text_line;
    reg [7:0] ch;
    reg [10:0] dx,dy;
    reg [5:0] char_index;
    reg [2:0] col,row;
    reg panel,character_valid;
    reg [7:0] character_q;
    reg [2:0] col_q,row_q;
    reg panel_q,character_valid_q;
    reg [23:0] base_rgb_q;
    integer n;
    reg [3:0] nibble;
    always @(*) begin
        text_line="                                ";
        panel=0;dx=0;dy=0;char_index=0;col=0;row=0;ch=" ";character_valid=0;nibble=0;
        if(i_x>=16 && i_x<544 && i_y>=72 && i_y<(DETECTION_OVERLAY ? 256 : 232)) begin
            panel=1;dx=i_x-24;dy=i_y-76;
            if(i_y<92) begin
                text_line="FPS:000 MANUAL                  ";
                text_line[4*8 +: 8]="0"+dh;
                text_line[5*8 +: 8]="0"+dt;
                text_line[6*8 +: 8]="0"+du;
            end else if(i_y<112) begin
                dy=i_y-96;
                case(i_mode)
                    0:text_line="MODE:BASIC SOBEL                ";
                    1:text_line="MODE:MED SOBEL                  ";
                    3:text_line="MODE:CANNY EXACT8               ";
                    default:text_line="MODE:CANNY LOCAL                ";
                endcase
                if(EXTENDED_RECOGNITION&&i_digit_mode)text_line="MODE:DIGITS GRAY TH             ";
                if(HAND_RECOGNITION&&i_digit_mode&&i_mode==3)text_line="MODE:HANDS 1-10 V3.1            ";
            end else if(i_y<136) begin
                dy=i_y-116;
                case(i_mode)
                    0:text_line="PYR3>GRAY>SOBEL>TH              ";
                    1:text_line="PYR3>MED>SOBEL>TH               ";
                    3:text_line="PYR3>MED>GRAD>NMS>DUAL>DFS8     ";
                    default:text_line="PYR3>MED>GRAD>NMS>DUAL>LOCAL    ";
                endcase
                if(HAND_RECOGNITION&&i_digit_mode&&i_mode==3)text_line="LIVE HAND OUTLINE + CLASSIFY    ";
            end else if(i_y<160) begin
                dy=i_y-144;
                text_line="LIVE   ID:00000000 N:0 AGE:0    ";
                if(i_freeze) text_line[0+:7*8]="FREEZE ";
                if(i_freeze&&i_age!=0) text_line[0+:7*8]="REPLAY ";
                if(i_fault) text_line[0+:7*8]="FAULT  ";
                for(n=0;n<8;n=n+1) begin
                    nibble=i_frame>>((7-n)*4);
                    text_line[(10+n)*8+:8]=nibble<10 ? "0"+nibble : "A"+nibble-10;
                end
                text_line[21*8+:8]="0"+i_history_count;
                text_line[27*8+:8]="0"+i_age;
            end else if(i_y<184) begin
                dy=i_y-164;
                case(i_view)
                    0:text_line="VIEW:GRAY EDGE SPLIT            ";
                    1:text_line="VIEW:RGB RED EDGES              ";
                    default:text_line="VIEW:ORIGINAL RGB               ";
                endcase
                if(HAND_RECOGNITION&&i_digit_mode&&i_mode==3&&i_view==0)text_line="VIEW:GRAY ZOOM HAND MASK        ";
                if(HAND_RECOGNITION&&i_digit_mode&&i_mode==3&&i_view==1)text_line="VIEW:LIVE RGB RED OUTLINE       ";
            end else if(i_y<208) begin
                dy=i_y-188;
                if(HAND_RECOGNITION&&i_digit_mode&&i_mode==3)begin
                    if(!i_shape_ready)text_line="HAND:WAIT FRAME OR CONFIG       ";
                    else if(i_shape_class>=5&&i_shape_class<=14)begin
                        text_line="HAND:0                          ";
                        if(i_shape_class==14)begin text_line[5*8+:8]="1";text_line[6*8+:8]="0";end
                        else text_line[5*8+:8]="0"+i_shape_class-4;
                    end else if(i_shape_class==3)text_line="HAND:MULTIPLE OR LIMIT          ";
                    else case(i_shape_reason)
                        1:text_line="HAND:NO SKIN                    ";
                        2:text_line="HAND:SIZE OR DENSITY            ";
                        3:text_line="HAND:MOVE INSIDE ROI            ";
                        6:text_line="HAND:NO MATCH                   ";
                        7:text_line="HAND:AMBIGUOUS                  ";
                        9:text_line="HAND:LOW SCORE GAP              ";
                        10:text_line="HAND:HOLD STILL CONFIRM         ";
                        default:text_line="HAND:UNKNOWN                    ";
                    endcase
                end else if(!i_shape_ready) text_line=EXTENDED_RECOGNITION&&i_digit_mode ? "DIGIT:WAIT FRAME OR CONFIG      " : "SHAPE:WAIT FRAME OR CONFIG      ";
                else if(EXTENDED_RECOGNITION&&i_digit_mode)begin
                    if(i_shape_class>=5&&i_shape_class<=14)begin
                        text_line="DIGIT:0                         ";text_line[6*8+:8]="0"+i_shape_class-5;
                    end else if(i_shape_class==3) text_line="DIGIT:MULTIPLE OR LIMIT         ";
                    else case(i_shape_reason)
                        1:text_line="DIGIT:NO FOREGROUND             ";
                        2:text_line="DIGIT:TOO SMALL                 ";
                        3:text_line="DIGIT:MOVE INSIDE ROI           ";
                        6:text_line="DIGIT:NO MATCH CHECK GRAY TH    ";
                        7:text_line="DIGIT:AMBIGUOUS                 ";
                        default:text_line="DIGIT:UNKNOWN                   ";
                    endcase
                end else case(i_shape_class)
                    1:text_line="SHAPE:CIRCLE                    ";
                    2:text_line="SHAPE:RECTANGLE                 ";
                    3:text_line="SHAPE:MULTIPLE OR LIMIT         ";
                    4:text_line="SHAPE:TRIANGLE                  ";
                    default:text_line="SHAPE:UNKNOWN                   ";
                endcase
            end else if(i_y<232) begin
                dy=i_y-212;
                text_line="EXACT:IDLE   T:00000000         ";
                case(i_exact_status)
                    1:text_line[6*8+:7*8]="CAPTURE";
                    2:text_line[6*8+:7*8]="TRACE  ";
                    3:text_line[6*8+:7*8]="FLUSH  ";
                    4:text_line[6*8+:7*8]="READY  ";
                    5:text_line[6*8+:7*8]="FAULT  ";
                    default:;
                endcase
                for(n=0;n<8;n=n+1) begin
                    nibble=i_exact_cycles>>((7-n)*4);
                    text_line[(15+n)*8+:8]=nibble<10 ? "0"+nibble : "A"+nibble-10;
                end
                if(HAND_RECOGNITION&&i_digit_mode&&i_mode==3)begin
                    text_line="PICK:WAIT CANDIDATE             ";
                    if(i_shape_ready&&i_hand_raw<=10)begin
                        text_line="PICK:00  RAW HAND CLASS         ";
                        text_line[5*8+:8]=i_hand_raw==10?"1":"0";
                        text_line[6*8+:8]=i_hand_raw==10?"0":"0"+i_hand_raw;
                    end
                end
            end else begin
                dy=i_y-236;
                if(!i_shape_ready) text_line="DET:2HZ ROI WAIT                ";
                else begin
                    text_line="DET:2HZ ROI AGE:00              ";
                    text_line[16*8+:8]=i_shape_age[7:4]<10 ? "0"+i_shape_age[7:4] : "A"+i_shape_age[7:4]-10;
                    text_line[17*8+:8]=i_shape_age[3:0]<10 ? "0"+i_shape_age[3:0] : "A"+i_shape_age[3:0]-10;
                end
                if(EXTENDED_RECOGNITION) text_line[24*8+:7*8]=i_digit_mode ? "DIGITS " : "SHAPES ";
                if(HAND_RECOGNITION&&i_digit_mode&&i_mode==3)text_line[24*8+:7*8]="HANDS  ";
            end
            // Power-of-two character cells keep divide/modulo out of HDMI.
            char_index=dx>>4;col=dx[3:1];row=dy>>1;
            if(i_x>=24 && char_index<32 && col<5 && dy<14) begin
                ch=text_line[char_index*8 +: 8];character_valid=1;
            end
        end
    end
    // Split row/text selection from the font lookup at 148.5 MHz.  The RGB
    // passthrough and all three controls share this exact one-pixel delay.
    always @(posedge i_clk or negedge i_rst_n) begin
        if(!i_rst_n) begin
            character_q<=0;col_q<=0;row_q<=0;panel_q<=0;character_valid_q<=0;
            base_rgb_q<=0;o_de<=0;o_hs<=0;o_vs<=0;
        end else begin
            character_q<=ch;col_q<=col;row_q<=row;panel_q<=panel;
            character_valid_q<=character_valid;base_rgb_q<={th_r,th_g,th_b};
            o_de<=i_de;o_hs<=i_hs;o_vs<=i_vs;
        end
    end
    wire [34:0] pixels=glyph(character_q);
    // Sized arithmetic avoids a 32-bit variable bit-select in the pixel path.
    wire [5:0] font_index=6'd34-({3'd0,row_q}<<2)-{3'd0,row_q}-{3'd0,col_q};
    wire on=character_valid_q && pixels[font_index];
    always @(*) begin
        {o_r,o_g,o_b}=base_rgb_q;
        if(o_de && panel_q) begin
            o_r=on ? 8'hff : 8'h08;o_g=on ? 8'hff : 8'h08;o_b=on ? 8'h00 : 8'h08;
        end
    end
endmodule
