// Bundled-data mailbox. Source holds payload until destination acknowledges.
module config_cdc #(
    parameter integer WIDTH=14,
    parameter [WIDTH-1:0] RESET_VALUE=0
) (
    input wire i_src_clk,i_src_rst_n,
    input wire [WIDTH-1:0] i_data,
    input wire i_dst_clk,i_dst_rst_n,
    output reg [WIDTH-1:0] o_data,
    output reg o_ready
);
    reg [WIDTH-1:0] payload;
    reg req,ack;
    (* async_reg="true" *) reg [1:0] ack_sync,req_sync;
    always @(posedge i_src_clk or negedge i_src_rst_n) begin
        if(!i_src_rst_n) begin payload<=RESET_VALUE;req<=0;ack_sync<=0;end
        else begin
            ack_sync<={ack_sync[0],ack};
            if(req==ack_sync[1] && i_data!=payload) begin payload<=i_data;req<=~req;end
        end
    end
    always @(posedge i_dst_clk or negedge i_dst_rst_n) begin
        if(!i_dst_rst_n) begin req_sync<=0;ack<=0;o_data<=RESET_VALUE;o_ready<=0;end
        else begin
            req_sync<={req_sync[0],req};o_ready<=1;
            if(req_sync[1]!=ack) begin o_data<=payload;ack<=req_sync[1];end
        end
    end
endmodule
