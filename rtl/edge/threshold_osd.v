// HDMI threshold on-screen display.
// Draws TH:dddd with a 5x7 font scaled 4x, using an opaque background.
module threshold_osd #(
    parameter integer DEFAULT_THRESHOLD = 128
) (
    input  wire        i_clk,
    input  wire        i_rst_n,
    input  wire        i_de,
    input  wire [10:0] i_x,
    input  wire [10:0] i_y,
    input  wire [11:0] i_threshold,
    input  wire [7:0]  i_r,
    input  wire [7:0]  i_g,
    input  wire [7:0]  i_b,
    output reg  [7:0]  o_r,
    output reg  [7:0]  o_g,
    output reg  [7:0]  o_b
);
    localparam [2:0] BCD_IDLE=0, BCD_THOUSANDS=1, BCD_HUNDREDS=2,
                     BCD_TENS=3, BCD_ONES=4;
    localparam [10:0] BOX_X0=11'd16, BOX_X1=11'd196;
    localparam [10:0] BOX_Y0=11'd16, BOX_Y1=11'd60;
    localparam [10:0] TEXT_X=11'd24, TEXT_Y=11'd24;

    reg [2:0] bcd_state;
    reg [11:0] threshold_seen;
    reg [11:0] bcd_remainder;
    reg [3:0] work_thousands, work_hundreds, work_tens;
    reg [3:0] digit_thousands, digit_hundreds, digit_tens, digit_ones;

    // Repeated subtraction runs only after a key change.  It avoids divider
    // logic in the 148.5 MHz pixel path and commits all four digits together.
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            bcd_state       <= BCD_IDLE;
            threshold_seen  <= 12'hfff;
            bcd_remainder   <= 12'd0;
            work_thousands  <= 4'd0;
            work_hundreds   <= 4'd0;
            work_tens       <= 4'd0;
            digit_thousands <= (DEFAULT_THRESHOLD / 1000) % 10;
            digit_hundreds  <= (DEFAULT_THRESHOLD / 100) % 10;
            digit_tens      <= (DEFAULT_THRESHOLD / 10) % 10;
            digit_ones      <= DEFAULT_THRESHOLD % 10;
        end else begin
            case (bcd_state)
                BCD_IDLE: begin
                    if (i_threshold != threshold_seen) begin
                        threshold_seen <= i_threshold;
                        bcd_remainder  <= i_threshold;
                        work_thousands <= 4'd0;
                        work_hundreds  <= 4'd0;
                        work_tens      <= 4'd0;
                        bcd_state      <= BCD_THOUSANDS;
                    end
                end
                BCD_THOUSANDS: begin
                    if (bcd_remainder >= 12'd1000) begin
                        bcd_remainder  <= bcd_remainder - 12'd1000;
                        work_thousands <= work_thousands + 1'b1;
                    end else
                        bcd_state <= BCD_HUNDREDS;
                end
                BCD_HUNDREDS: begin
                    if (bcd_remainder >= 12'd100) begin
                        bcd_remainder <= bcd_remainder - 12'd100;
                        work_hundreds <= work_hundreds + 1'b1;
                    end else
                        bcd_state <= BCD_TENS;
                end
                BCD_TENS: begin
                    if (bcd_remainder >= 12'd10) begin
                        bcd_remainder <= bcd_remainder - 12'd10;
                        work_tens     <= work_tens + 1'b1;
                    end else
                        bcd_state <= BCD_ONES;
                end
                BCD_ONES: begin
                    digit_thousands <= work_thousands;
                    digit_hundreds  <= work_hundreds;
                    digit_tens      <= work_tens;
                    digit_ones      <= bcd_remainder[3:0];
                    bcd_state       <= BCD_IDLE;
                end
                default: bcd_state <= BCD_IDLE;
            endcase
        end
    end

    // Character codes: 0..9 = digits, 10 = T, 11 = H, 12 = colon.
    function [4:0] glyph_row;
        input [3:0] character;
        input [2:0] row;
        begin
            glyph_row = 5'b00000;
            case (character)
                4'd0: case(row)
                    0:glyph_row=5'b01110; 1:glyph_row=5'b10001; 2:glyph_row=5'b10011;
                    3:glyph_row=5'b10101; 4:glyph_row=5'b11001; 5:glyph_row=5'b10001;
                    6:glyph_row=5'b01110; default:glyph_row=0; endcase
                4'd1: case(row)
                    0:glyph_row=5'b00100; 1:glyph_row=5'b01100; 2:glyph_row=5'b00100;
                    3:glyph_row=5'b00100; 4:glyph_row=5'b00100; 5:glyph_row=5'b00100;
                    6:glyph_row=5'b01110; default:glyph_row=0; endcase
                4'd2: case(row)
                    0:glyph_row=5'b01110; 1:glyph_row=5'b10001; 2:glyph_row=5'b00001;
                    3:glyph_row=5'b00010; 4:glyph_row=5'b00100; 5:glyph_row=5'b01000;
                    6:glyph_row=5'b11111; default:glyph_row=0; endcase
                4'd3: case(row)
                    0:glyph_row=5'b11110; 1:glyph_row=5'b00001; 2:glyph_row=5'b00001;
                    3:glyph_row=5'b01110; 4:glyph_row=5'b00001; 5:glyph_row=5'b00001;
                    6:glyph_row=5'b11110; default:glyph_row=0; endcase
                4'd4: case(row)
                    0:glyph_row=5'b00010; 1:glyph_row=5'b00110; 2:glyph_row=5'b01010;
                    3:glyph_row=5'b10010; 4:glyph_row=5'b11111; 5:glyph_row=5'b00010;
                    6:glyph_row=5'b00010; default:glyph_row=0; endcase
                4'd5: case(row)
                    0:glyph_row=5'b11111; 1:glyph_row=5'b10000; 2:glyph_row=5'b10000;
                    3:glyph_row=5'b11110; 4:glyph_row=5'b00001; 5:glyph_row=5'b00001;
                    6:glyph_row=5'b11110; default:glyph_row=0; endcase
                4'd6: case(row)
                    0:glyph_row=5'b01110; 1:glyph_row=5'b10000; 2:glyph_row=5'b10000;
                    3:glyph_row=5'b11110; 4:glyph_row=5'b10001; 5:glyph_row=5'b10001;
                    6:glyph_row=5'b01110; default:glyph_row=0; endcase
                4'd7: case(row)
                    0:glyph_row=5'b11111; 1:glyph_row=5'b00001; 2:glyph_row=5'b00010;
                    3:glyph_row=5'b00100; 4:glyph_row=5'b01000; 5:glyph_row=5'b01000;
                    6:glyph_row=5'b01000; default:glyph_row=0; endcase
                4'd8: case(row)
                    0:glyph_row=5'b01110; 1:glyph_row=5'b10001; 2:glyph_row=5'b10001;
                    3:glyph_row=5'b01110; 4:glyph_row=5'b10001; 5:glyph_row=5'b10001;
                    6:glyph_row=5'b01110; default:glyph_row=0; endcase
                4'd9: case(row)
                    0:glyph_row=5'b01110; 1:glyph_row=5'b10001; 2:glyph_row=5'b10001;
                    3:glyph_row=5'b01111; 4:glyph_row=5'b00001; 5:glyph_row=5'b00001;
                    6:glyph_row=5'b01110; default:glyph_row=0; endcase
                4'd10: case(row)
                    0:glyph_row=5'b11111; 1:glyph_row=5'b00100; 2:glyph_row=5'b00100;
                    3:glyph_row=5'b00100; 4:glyph_row=5'b00100; 5:glyph_row=5'b00100;
                    6:glyph_row=5'b00100; default:glyph_row=0; endcase
                4'd11: case(row)
                    0:glyph_row=5'b10001; 1:glyph_row=5'b10001; 2:glyph_row=5'b10001;
                    3:glyph_row=5'b11111; 4:glyph_row=5'b10001; 5:glyph_row=5'b10001;
                    6:glyph_row=5'b10001; default:glyph_row=0; endcase
                4'd12: case(row)
                    0:glyph_row=5'b00000; 1:glyph_row=5'b00100; 2:glyph_row=5'b00100;
                    3:glyph_row=5'b00000; 4:glyph_row=5'b00100; 5:glyph_row=5'b00100;
                    6:glyph_row=5'b00000; default:glyph_row=0; endcase
                default: glyph_row=5'b00000;
            endcase
        end
    endfunction

    wire in_box = (i_x >= BOX_X0) && (i_x < BOX_X1) &&
                  (i_y >= BOX_Y0) && (i_y < BOX_Y1);
    wire on_border = in_box && ((i_x == BOX_X0) || (i_x == BOX_X1-1'b1) ||
                                (i_y == BOX_Y0) || (i_y == BOX_Y1-1'b1));
    wire in_text_y = (i_y >= TEXT_Y) && (i_y < TEXT_Y + 11'd28);
    wire [2:0] text_row = (i_y - TEXT_Y) >> 2;
    reg [3:0] character;
    reg [2:0] text_col;
    reg       character_valid;
    reg [4:0] row_pixels;

    always @(*) begin
        character = 4'd0;
        text_col = 3'd0;
        character_valid = 1'b0;
        if (in_text_y) begin
            if ((i_x >= TEXT_X) && (i_x < TEXT_X+20)) begin
                character=4'd10; text_col=(i_x-TEXT_X)>>2; character_valid=1;
            end else if ((i_x >= TEXT_X+24) && (i_x < TEXT_X+44)) begin
                character=4'd11; text_col=(i_x-(TEXT_X+24))>>2; character_valid=1;
            end else if ((i_x >= TEXT_X+48) && (i_x < TEXT_X+68)) begin
                character=4'd12; text_col=(i_x-(TEXT_X+48))>>2; character_valid=1;
            end else if ((i_x >= TEXT_X+72) && (i_x < TEXT_X+92)) begin
                character=digit_thousands; text_col=(i_x-(TEXT_X+72))>>2; character_valid=1;
            end else if ((i_x >= TEXT_X+96) && (i_x < TEXT_X+116)) begin
                character=digit_hundreds; text_col=(i_x-(TEXT_X+96))>>2; character_valid=1;
            end else if ((i_x >= TEXT_X+120) && (i_x < TEXT_X+140)) begin
                character=digit_tens; text_col=(i_x-(TEXT_X+120))>>2; character_valid=1;
            end else if ((i_x >= TEXT_X+144) && (i_x < TEXT_X+164)) begin
                character=digit_ones; text_col=(i_x-(TEXT_X+144))>>2; character_valid=1;
            end
        end
        row_pixels = glyph_row(character, text_row);
    end

    wire glyph_on = character_valid && row_pixels[4-text_col];

    always @(*) begin
        o_r = i_r;
        o_g = i_g;
        o_b = i_b;
        if (i_de && in_box) begin
            if (on_border) begin
                o_r = 8'h00; o_g = 8'hff; o_b = 8'hff; // cyan border
            end else if (glyph_on) begin
                o_r = 8'hff; o_g = 8'hff; o_b = 8'h00; // yellow text
            end else begin
                o_r = 8'h08; o_g = 8'h08; o_b = 8'h08; // opaque dark background
            end
        end
    end
endmodule
