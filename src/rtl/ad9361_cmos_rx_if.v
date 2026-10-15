`timescale 1ns/1ps

// AD9361 6-bit CMOS DDR receive interface. RX_FRAME selects I (0) / Q (1).
module ad9361_cmos_rx_if (
    input  wire              data_clk,
    input  wire              rst_n,
    input  wire [5:0]        rx_data,
    input  wire              rx_frame,
    output reg signed [11:0] rx_i,
    output reg signed [11:0] rx_q,
    output reg               sample_valid
);
   (* mark_debug = "true" *) wire [5:0] data_rise;
   (* mark_debug = "true" *) wire [5:0] data_fall;
   (* mark_debug = "true" *) wire frame_rise;
   (* mark_debug = "true" *) wire frame_fall;

    genvar k;
    generate for (k = 0; k < 6; k = k + 1) begin : g_rx_iddr
        IDDR #(.DDR_CLK_EDGE("SAME_EDGE_PIPELINED"), .SRTYPE("ASYNC")) u_iddr (
            .Q1(data_rise[k]), .Q2(data_fall[k]), .C(data_clk), .CE(1'b1),
            .D(rx_data[k]), .R(!rst_n), .S(1'b0));
    end endgenerate
    IDDR #(.DDR_CLK_EDGE("SAME_EDGE_PIPELINED"), .SRTYPE("ASYNC")) u_frame_iddr (
        .Q1(frame_rise), .Q2(frame_fall), .C(data_clk), .CE(1'b1),
        .D(rx_frame), .R(!rst_n), .S(1'b0));

      reg have_i;
      always @(posedge data_clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_i        <= 12'sd0;
            rx_q        <= 12'sd0;
            sample_valid <= 1'b0;
            have_i      <= 1'b0;
        end else begin
            sample_valid <= 1'b0;
    
            if (!frame_rise) begin
                rx_i   <= $signed({data_rise, data_fall});
                have_i <= 1'b1;
            end else begin
                rx_q <= $signed({data_rise, data_fall});
    
                if (have_i) begin
                    sample_valid <= 1'b1;
                    have_i <= 1'b0;
                end
            end
        end
    end
endmodule
