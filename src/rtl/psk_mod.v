//============================================================================
// psk_mod.v  ——  BPSK / QPSK 调制 (网络模式下行)
//   bit -> 符号映射(±A) -> 冲激串 -> RRC成形 -> I/Q  (线性调制, 非恒包络)
//   mode: 0=BPSK (1bit/符号, Q=0)   1=QPSK (2bit/符号, Gray)
//   符号率 Rs: BPSK Rs=Rb, QPSK Rs=Rb/2 (调用方按 OSR 给 sym_en)
//============================================================================
module psk_mod #(
    parameter IQ_W = 12,
    parameter signed [IQ_W-1:0] A = 12'sd950   // 符号幅度
)(
    input                        clk,
    input                        rst_n,
    input                        sample_en,   // Fs 节拍
    input                        sym_en,      // 符号节拍 (每 OSR 个 sample_en)
    input                        mode,        // 0=BPSK 1=QPSK
    input      [1:0]             din,         // 本符号比特: BPSK 用 din[0]
    output     signed [IQ_W-1:0] i_out,
    output     signed [IQ_W-1:0] q_out,
    output     signed [IQ_W-1:0] i_imp_debug,
    output     signed [IQ_W-1:0] q_imp_debug,
    output     [1:0]             din_used_debug
);
    // ---- 符号映射 (冲激: 仅在 sym_en 拍给符号值, 其余 0) ----
    reg signed [IQ_W-1:0] i_imp, q_imp;
    reg [1:0] din_used;
    reg signed [IQ_W-1:0] i_map_hold, q_map_hold;
    assign i_imp_debug = i_map_hold;
    assign q_imp_debug = q_map_hold;
    assign din_used_debug = din_used;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin i_imp<=0; q_imp<=0; din_used<=0; i_map_hold<=0; q_map_hold<=0; end
        else if (sample_en) begin
            if (sym_en) begin
                din_used <= din;
                i_imp <= din[0] ? A : -A;
                q_imp <= mode ? (din[1] ? A : -A) : {IQ_W{1'b0}};
                i_map_hold <= din[0] ? A : -A;
                q_map_hold <= mode ? (din[1] ? A : -A) : {IQ_W{1'b0}};
            end else begin
                i_imp <= {IQ_W{1'b0}};
                q_imp <= {IQ_W{1'b0}};
            end
        end
    end

    // ---- RRC 成形 (I/Q 各一路) ----
    fir_sym #(.MEMFILE("rrc_coef.mem"), .DW(IQ_W)) u_i (
        .clk(clk), .rst_n(rst_n), .sample_en(sample_en), .din(i_imp), .dout(i_out));
    fir_sym #(.MEMFILE("rrc_coef.mem"), .DW(IQ_W)) u_q (
        .clk(clk), .rst_n(rst_n), .sample_en(sample_en), .din(q_imp), .dout(q_out));
endmodule
