// Efinity DDR3 Soft Controller 5.16, generated for the board's x16 DDR3.
// The application remains at 100 MHz; the DDR PHY runs at 200/400 MHz.
// One outstanding burst per direction matches axi_video_arbiter ownership.
module efinity_ddr3_adapter (
    input wire clk, ddr_core_clk, dq_clk, ck_clk, rx_clk, rst_n,
    output wire [2:0] pll_shift,
    output wire [4:0] pll_shift_sel,
    output wire pll_shift_ena,
    output wire cal_ready,
    output wire ddr_reset_n, ddr_cs_n, ddr_ras_n, ddr_cas_n, ddr_we_n,
    output wire ddr_cke, ddr_odt,
    output wire [13:0] ddr_addr,
    output wire [2:0] ddr_ba,
    input wire [1:0] dqs_hi, dqs_lo,
    input wire [15:0] dq_hi, dq_lo,
    output wire [1:0] dqs_out_hi, dqs_out_lo, dqs_oe, dqs_oe_n,
    output wire [15:0] dq_out_hi, dq_out_lo, dq_oe,
    output wire [1:0] dm_hi, dm_lo,
    input wire [3:0] awid,
    input wire [31:0] awaddr,
    input wire [7:0] awlen,
    input wire [2:0] awsize,
    input wire [1:0] awburst,
    input wire awlock, awvalid,
    output wire awready,
    input wire [127:0] wdata,
    input wire [15:0] wstrb,
    input wire wlast, wvalid,
    output wire wready,
    output wire [3:0] bid,
    output wire [1:0] bresp,
    output wire bvalid,
    input wire bready,
    input wire [3:0] arid,
    input wire [31:0] araddr,
    input wire [7:0] arlen,
    input wire [2:0] arsize,
    input wire [1:0] arburst,
    input wire arlock, arvalid,
    output wire arready,
    output wire [3:0] rid,
    output wire [127:0] rdata,
    output wire [1:0] rresp,
    output wire rlast, rvalid,
    input wire rready
);
    wire ip_cal_done, ip_cal_pass;
    // Vendor status originates in its calibration clock domain.
    (* ASYNC_REG = "TRUE" *) reg [1:0] ready_sync;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) ready_sync <= 0;
        else ready_sync <= {ready_sync[0], ip_cal_done && ip_cal_pass};
    end
    assign cal_ready = ready_sync[1];

    // The IP combines AW and AR into one address channel. Hold the grant
    // through backpressure so neither address nor its type can change.
    reg address_active, address_write, prefer_write;
    reg write_active;
    reg [3:0] write_id;
    wire ip_aready, ip_wready;
    wire address_valid = cal_ready && address_active &&
                         (address_write ? awvalid : arvalid);
    assign awready = cal_ready && address_active && address_write && ip_aready;
    assign arready = cal_ready && address_active && !address_write && ip_aready;
    assign wready = cal_ready && write_active && ip_wready;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            address_active <= 0; address_write <= 0; prefer_write <= 0;
            write_active <= 0; write_id <= 0;
        end else if (!cal_ready) begin
            address_active <= 0; write_active <= 0;
        end else begin
            if (!address_active && (awvalid || arvalid)) begin
                address_active <= 1;
                address_write <= awvalid && (!arvalid || prefer_write);
            end else if (address_valid && ip_aready) begin
                address_active <= 0;
                prefer_write <= !address_write;
            end
            if (awvalid && awready) begin write_id <= awid; write_active <= 1; end
            if (bvalid && bready) write_active <= 0;
        end
    end

    wire [7:0] ip_bid, ip_rid;
    wire [15:0] ip_addr;
    assign bid = ip_bid[3:0];
    assign rid = ip_rid[3:0];
    assign ddr_addr = ip_addr[13:0];

    ddr3_official u_ddr3_ip (
        .clk(clk), .core_clk(ddr_core_clk), .twd_clk(dq_clk),
        .tdqss_clk(ck_clk), .tac_clk(rx_clk), .reset_n(rst_n),
        .reset(ddr_reset_n), .cs(ddr_cs_n), .ras(ddr_ras_n),
        .cas(ddr_cas_n), .we(ddr_we_n), .cke(ddr_cke),
        .addr(ip_addr), .ba(ddr_ba), .odt(ddr_odt),
        .o_dm_hi(dm_hi), .o_dm_lo(dm_lo),
        .i_dqs_hi(dqs_hi), .i_dqs_lo(dqs_lo),
        .i_dqs_n_hi(~dqs_hi), .i_dqs_n_lo(~dqs_lo),
        .o_dqs_hi(dqs_out_hi), .o_dqs_lo(dqs_out_lo),
        .o_dqs_n_hi(), .o_dqs_n_lo(), .o_dqs_oe(dqs_oe), .o_dqs_n_oe(dqs_oe_n),
        .i_dq_hi(dq_hi), .i_dq_lo(dq_lo),
        .o_dq_hi(dq_out_hi), .o_dq_lo(dq_out_lo), .o_dq_oe(dq_oe),
        .shift(pll_shift), .shift_sel(pll_shift_sel), .shift_ena(pll_shift_ena),
        .cal_ena(1'b1), .cal_done(ip_cal_done), .cal_pass(ip_cal_pass),
        .cal_shift_val(), .cal_fail_log(),
        .axi_aid({4'd0, address_write ? awid : arid}),
        .axi_aaddr(address_write ? awaddr : araddr),
        .axi_alen(address_write ? awlen : arlen),
        .axi_asize(address_write ? awsize : arsize),
        .axi_aburst(address_write ? awburst : arburst),
        .axi_alock({1'b0, address_write ? awlock : arlock}),
        .axi_avalid(address_valid), .axi_aready(ip_aready), .axi_atype(address_write),
        .axi_wid({4'd0, write_id}), .axi_wdata(wdata), .axi_wstrb(wstrb),
        .axi_wlast(wlast), .axi_wvalid(cal_ready && write_active && wvalid),
        .axi_wready(ip_wready),
        .axi_bid(ip_bid), .axi_bresp(bresp), .axi_bvalid(bvalid), .axi_bready(bready),
        .axi_rid(ip_rid), .axi_rdata(rdata), .axi_rresp(rresp),
        .axi_rlast(rlast), .axi_rvalid(rvalid), .axi_rready(rready)
    );
endmodule
