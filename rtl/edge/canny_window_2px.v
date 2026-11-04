// Three rows and four columns for two adjacent 3x3 windows.
// Every DE cycle advances two pixels. Blanking is at least four clocks.
// Data is centred one row earlier; sync/DE retain the full input raster.
// BORDER masks the accumulated radius of cascaded window stages.
module canny_window_2px #(
    parameter integer H_ACTIVE = 1920,
    parameter integer DATA_WIDTH = 8,
    parameter integer BORDER = 1
) (
    input wire i_clk, i_rst_n,
    input wire i_vs, i_hs, i_de,
    input wire [2*DATA_WIDTH-1:0] i_data,
    output wire o_vs, o_hs, o_de,
    output wire o_mask0, o_mask1,
    output wire [11:0] o_pair,
    // Low slice is the leftmost pixel: x-1, x, x+1, x+2.
    output wire [4*DATA_WIDTH-1:0] o_top, o_mid, o_bot
);
    localparam integer PAIRS = H_ACTIVE / 2;
    localparam integer AW = $clog2(PAIRS);
    reg [AW-1:0] x;
    reg [11:0] y;
    reg de_prev, vs_prev;
    wire frame_start = i_vs && !vs_prev;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            x <= 0; y <= 0; de_prev <= 0; vs_prev <= 0;
        end else begin
            de_prev <= i_de;
            vs_prev <= i_vs;
            if (frame_start) begin x <= 0; y <= 0; end
            else begin
                if (i_de) x <= x + 1'b1;
                else x <= 0;
                if (de_prev && !i_de) y <= y + 1'b1;
            end
        end
    end

    wire [2*DATA_WIDTH-1:0] row1, row2;
    reg [2*DATA_WIDTH-1:0] bot1, bot2, mid2;
    reg [AW-1:0] x1, x2, x3;
    reg [11:0] y1, y2, y3;
    reg [2:0] de_d, hs_d, vs_d;
    true_dual_port_ram #(
        .DATA_WIDTH(2*DATA_WIDTH), .ADDR_WIDTH(AW), .RAM_INIT_FILE("")
    ) u_line1 (
        .we1(i_de), .we2(1'b0), .clka(i_clk), .clkb(i_clk),
        .din1(i_data), .din2({2*DATA_WIDTH{1'b0}}),
        .addr1(x), .addr2({AW{1'b0}}), .dout1(row1), .dout2()
    );
    true_dual_port_ram #(
        .DATA_WIDTH(2*DATA_WIDTH), .ADDR_WIDTH(AW), .RAM_INIT_FILE("")
    ) u_line2 (
        .we1(de_d[0]), .we2(1'b0), .clka(i_clk), .clkb(i_clk),
        .din1(row1), .din2({2*DATA_WIDTH{1'b0}}),
        .addr1(x1), .addr2({AW{1'b0}}), .dout1(row2), .dout2()
    );

    reg [2*DATA_WIDTH-1:0] top_prev, mid_prev, bot_prev;
    reg [2*DATA_WIDTH-1:0] top_left, mid_left, bot_left;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            bot1 <= 0; bot2 <= 0; mid2 <= 0;
            top_prev <= 0; mid_prev <= 0; bot_prev <= 0;
            top_left <= 0; mid_left <= 0; bot_left <= 0;
            x1 <= 0; x2 <= 0; x3 <= 0;
            y1 <= 0; y2 <= 0; y3 <= 0;
            de_d <= 0; hs_d <= 0; vs_d <= 0;
        end else begin
            bot1 <= i_data; bot2 <= bot1; mid2 <= row1;
            top_prev <= row2; mid_prev <= mid2; bot_prev <= bot2;
            top_left <= top_prev; mid_left <= mid_prev; bot_left <= bot_prev;
            x1 <= x; x2 <= x1; x3 <= x2;
            y1 <= y; y2 <= y1; y3 <= y2;
            de_d <= {de_d[1:0], i_de};
            hs_d <= {hs_d[1:0], i_hs};
            vs_d <= {vs_d[1:0], i_vs};
        end
    end
    assign o_top = {row2[DATA_WIDTH-1:0], top_prev, top_left[2*DATA_WIDTH-1:DATA_WIDTH]};
    assign o_mid = {mid2[DATA_WIDTH-1:0], mid_prev, mid_left[2*DATA_WIDTH-1:DATA_WIDTH]};
    assign o_bot = {bot2[DATA_WIDTH-1:0], bot_prev, bot_left[2*DATA_WIDTH-1:DATA_WIDTH]};
    wire [12:0] pixel_x = {1'b0, x3, 1'b0};
    assign o_pair = x3;
    assign o_mask0 = de_d[2] && (y3 >= 2*BORDER) &&
                     (pixel_x >= BORDER) && (pixel_x < H_ACTIVE-BORDER);
    assign o_mask1 = de_d[2] && (y3 >= 2*BORDER) &&
                     (pixel_x+1 >= BORDER) && (pixel_x+1 < H_ACTIVE-BORDER);
    assign o_vs = vs_d[2];
    assign o_hs = hs_d[2];
    assign o_de = de_d[2];
endmodule
