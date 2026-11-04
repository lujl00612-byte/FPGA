// Manual thresholds only. KEY2 short release: algorithm; long: freeze/live.
// KEY0+KEY1: view. Frozen KEY2+KEY0/KEY1: older/newer recorded frame.
module video_controls #(
    parameter integer CLK_HZ=74_250_000,
    parameter integer DEBOUNCE_MS=20,
    parameter integer HOLD_MS=400,
    parameter integer REPEAT_MS=80,
    parameter integer MODE_HOLD_MS=600,DEFAULT_VIEW=1,
    parameter integer EXTENDED_RECOGNITION=0,DIGIT_FEATURE_CONTROLS=0,HAND_RECOGNITION=0
) (
    input wire i_clk,i_rst_n,i_key0_n,i_key1_n,i_key2_n,
    output reg [11:0] o_threshold,
    output reg [1:0] o_mode,
    output reg [1:0] o_view,
    output reg o_freeze,
    output reg [7:0] o_step_sequence,
    output reg o_step_older,
    output reg o_digit_mode,
    output reg o_hand_mode
);
    localparam integer DEB=(CLK_HZ/1000)*DEBOUNCE_MS;
    localparam integer HLD=(CLK_HZ/1000)*HOLD_MS;
    localparam integer RPT=(CLK_HZ/1000)*REPEAT_MS;
    localparam integer LONG=(CLK_HZ/1000)*MODE_HOLD_MS;
    wire k0,k1,k2;
    key_level #(.CYCLES(DEB)) d0(.clk(i_clk),.rst_n(i_rst_n),.key_n(i_key0_n),.down(k0));
    key_level #(.CYCLES(DEB)) d1(.clk(i_clk),.rst_n(i_rst_n),.key_n(i_key1_n),.down(k1));
    key_level #(.CYCLES(DEB)) d2(.clk(i_clk),.rst_n(i_rst_n),.key_n(i_key2_n),.down(k2));
    reg [31:0] mode_count,threshold_count;
    reg [11:0] gesture_threshold,saved_edge_threshold;reg [7:0] saved_gray_threshold;
    reg mode_used,chord_used,repeat_active;
    reg [1:0] single_prev;
    wire [1:0] single=(!k2&&!(k0&&k1)) ? {k1,k0} : 2'd0;
    task adjust;
        input subtract;
        begin
            if(HAND_RECOGNITION&&o_hand_mode)o_threshold<=o_threshold;
            // Edge and printed-digit manual thresholds share32..192, step8.
            else if(subtract) o_threshold<=o_threshold<=12'd40 ? 12'd32 : o_threshold-12'd8;
            else o_threshold<=o_threshold>=12'd184 ? 12'd192 : o_threshold+12'd8;
        end
    endtask
    task switch_recognition;
        begin
            if(HAND_RECOGNITION&&o_hand_mode)begin
                o_hand_mode<=0;o_digit_mode<=1;o_mode<=0;o_threshold<={4'd0,saved_gray_threshold};
            end else begin
            o_digit_mode<=~o_digit_mode;
            if(DIGIT_FEATURE_CONTROLS)begin
                if(o_digit_mode)begin saved_gray_threshold<=gesture_threshold[7:0];o_threshold<=saved_edge_threshold;end
                else begin saved_edge_threshold<=gesture_threshold;o_threshold<={4'd0,saved_gray_threshold};end
            end
            end
        end
    endtask
    always @(posedge i_clk or negedge i_rst_n) begin
        if(!i_rst_n) begin
            o_threshold<=128;o_mode<=0;o_view<=DEFAULT_VIEW;o_freeze<=0;o_step_sequence<=0;o_step_older<=1;o_digit_mode<=0;o_hand_mode<=0;
            mode_count<=0;threshold_count<=0;mode_used<=0;chord_used<=0;repeat_active<=0;single_prev<=0;
            gesture_threshold<=128;saved_edge_threshold<=128;saved_gray_threshold<=128;
        end
        else begin
            single_prev<=single;
            if(!k0&&!k1&&!k2) begin chord_used<=0;gesture_threshold<=o_threshold;end
            if(k0&&k1&&!chord_used) begin
                chord_used<=1;o_threshold<=gesture_threshold;
                if(!k2) o_view<=o_view==2 ? 0 : o_view+1'b1;
                else mode_used<=1;
            end else if(k2&&(k0||k1)&&!chord_used) begin
                chord_used<=1;mode_used<=1;o_threshold<=gesture_threshold;
                if(o_freeze) begin o_step_sequence<=o_step_sequence+1'b1;o_step_older<=k0;end
                else if(EXTENDED_RECOGNITION&&k0) switch_recognition();
            end
            if(k2) begin
                if(!mode_used && !k0 && !k1) begin
                    if(mode_count==LONG-1) begin o_freeze<=~o_freeze;mode_used<=1;end
                    else mode_count<=mode_count+1'b1;
                end
            end else begin
                if(mode_count!=0&&!mode_used)begin
                    if(HAND_RECOGNITION&&o_hand_mode)begin
                        o_hand_mode<=0;o_digit_mode<=0;o_mode<=0;o_threshold<=saved_edge_threshold;
                    end else if(HAND_RECOGNITION&&o_digit_mode)begin
                        saved_gray_threshold<=gesture_threshold[7:0];o_hand_mode<=1;o_mode<=0;o_threshold<=saved_edge_threshold;o_view<=0;
                    end else if(EXTENDED_RECOGNITION&&DIGIT_FEATURE_CONTROLS&&(o_digit_mode||o_mode==2))begin
                        switch_recognition();if(o_digit_mode)o_mode<=0;
                    end else o_mode<=o_mode==2 ? 0 : o_mode+1'b1;
                end
                mode_count<=0;mode_used<=0;
            end
            if(single==0 || chord_used) begin threshold_count<=0;repeat_active<=0;end
            else if(single!=single_prev) begin adjust(single[1]);threshold_count<=0;repeat_active<=0;end
            else if(threshold_count==(repeat_active ? RPT-1 : HLD-1)) begin
                if(repeat_active) adjust(single[1]);
                threshold_count<=0;repeat_active<=1;
            end else threshold_count<=threshold_count+1'b1;
        end
    end
endmodule
