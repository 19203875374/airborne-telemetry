`timescale 1ns/1ps

// AD9361 1.8-V CMOS, 6-bit DDR transmit interface.
// The asynchronous FIFO is configured for FWFT. One 32-bit word contains
// {I[11:0], 4'b0, Q[11:0], 4'b0}; one word is consumed every two data clocks.
module ad9361_cmos_tx_if (
    input  wire        data_clk,
    input  wire        oddr_clk,
    input  wire        fb_clk,
    input  wire        rst_n,
    input  wire [31:0] fifo_dout,
    input  wire        fifo_empty,
    input  wire [7:0]  fifo_level,
    output wire        fifo_rd_en,
    output wire        tx_clk_out_p,
    output wire        tx_frame_out_p,
    output wire [5:0]  tx_data_out_p,
    output reg         underflow
);
(* mark_debug = "true" *) reg        half_sel;
(* mark_debug = "true" *) reg [31:0] sample_hold;
(* mark_debug = "true" *) reg [5:0]  tx_data_i;
(* mark_debug = "true" *) reg [5:0]  tx_data_q;
(* mark_debug = "true" *) reg        tx_frame;
(* mark_debug = "true" *) reg        running;

    // Capture and pop the current FWFT word on the lower-half cycle.
    assign fifo_rd_en = rst_n && running && !half_sel && !fifo_empty;

    always @(posedge data_clk or negedge rst_n) begin
        if (!rst_n) begin
            half_sel   <= 1'b0;
            sample_hold <= 32'd0;
            tx_data_i  <= 6'd0;
            tx_data_q  <= 6'd0;
            tx_frame   <= 1'b0;
            running    <= 1'b0;
            underflow  <= 1'b0;
        end else begin
            if (!running) begin
                tx_data_i <= 6'd0;
                tx_data_q <= 6'd0;
                tx_frame  <= 1'b0;
                half_sel  <= 1'b0;
                if (fifo_level >= 8'd32)
                    running <= 1'b1;
end else if (!half_sel) begin
    // 第一拍：发送低6位，FRAME=0
    tx_frame <= 1'b0;

    if (!fifo_empty) begin
        sample_hold <= fifo_dout;
        tx_data_i   <= fifo_dout[25:20];
        tx_data_q   <= fifo_dout[9:4];
    end else begin
        sample_hold <= 32'd0;
        tx_data_i   <= 6'd0;
        tx_data_q   <= 6'd0;
        underflow   <= 1'b1;
    end
end else begin
    // 第二拍：发送高6位，FRAME=1
    tx_frame  <= 1'b1;
    tx_data_i <= sample_hold[31:26];
    tx_data_q <= sample_hold[15:10];
end
            if (running)
                half_sel <= ~half_sel;
        end
    end

ODDR #(
    .DDR_CLK_EDGE("OPPOSITE_EDGE"),
    .INIT(1'b0),
    .SRTYPE("ASYNC")
) u_tx_frame_oddr (
    .CE(1'b1),
    .R(!rst_n),
    .S(1'b0),
    .C(oddr_clk),
    .D1(tx_frame),
    .D2(tx_frame),
    .Q(tx_frame_out_p)
);
    genvar k;
    generate
        for (k = 0; k < 6; k = k + 1) begin : g_tx_data
            ODDR #(
                .DDR_CLK_EDGE("OPPOSITE_EDGE"),
                .INIT(1'b0),
                .SRTYPE("ASYNC")
            ) u_tx_data_oddr (
                .CE(1'b1), .R(!rst_n), .S(1'b0), .C(oddr_clk),
                .D1(tx_data_i[k]), .D2(tx_data_q[k]), .Q(tx_data_out_p[k])
            );
        end
    endgenerate

    // This polarity and the 0x007=0x0F AD9361 PPORT TX delay are retained
    // from the transmitter project that was already verified on hardware.
    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT(1'b0),
        .SRTYPE("ASYNC")
    ) u_tx_clk_oddr (
        .CE(1'b1), .R(!rst_n), .S(1'b0), .C(fb_clk),
        .D1(1'b0), .D2(1'b1), .Q(tx_clk_out_p)
    );
endmodule
