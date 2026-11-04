// Counts actual video-frame sync edges in a one-second pixel-clock window.
// The result updates once per second so the OSD remains readable and stable.
module video_fps_meter #(
    parameter integer CLK_HZ = 148_500_000,
    parameter integer DEFAULT_FPS = 60
) (
    input  wire       i_clk,
    input  wire       i_rst_n,
    input  wire       i_vs,
    output reg  [7:0] o_fps
);
    localparam integer COUNT_WIDTH = (CLK_HZ <= 2) ? 1 : $clog2(CLK_HZ);
    localparam [COUNT_WIDTH-1:0] LAST_COUNT = CLK_HZ - 1;

    reg [COUNT_WIDTH-1:0] window_count;
    reg [7:0] frame_count;
    reg vs_d;
    wire vs_rise = i_vs && !vs_d;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            window_count <= {COUNT_WIDTH{1'b0}};
            frame_count  <= 8'd0;
            vs_d         <= 1'b0;
            o_fps        <= DEFAULT_FPS;
        end else begin
            vs_d <= i_vs;
            if (window_count == LAST_COUNT) begin
                window_count <= {COUNT_WIDTH{1'b0}};
                if (vs_rise && frame_count != 8'hff)
                    o_fps <= frame_count + 1'b1;
                else
                    o_fps <= frame_count;
                frame_count <= 8'd0;
            end else begin
                window_count <= window_count + 1'b1;
                if (vs_rise && frame_count != 8'hff)
                    frame_count <= frame_count + 1'b1;
            end
        end
    end
endmodule
