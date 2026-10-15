//============================================================================
// pcm_fm_mod.v  ——  PCM/FM (CPFSK) 调制核, IRIG-106 Tier 0
//   成形调制信号 mod_in -> 频率调制 -> 复基带 I/Q -> AD9361 TX DAC
//
//   瞬时频率 f=Δf*m(t), m∈[-1,+1]; 相位 θ=2π∫f; I=cos θ, Q=sin θ
//   IRIG-106: 峰值频偏 Δf=0.35*Rb (h=0.7), 频谱靠预调制 FIR 收窄到 1.16*Rb
//
//   每采样相位增量 = (mod_in/满偏) * dev_step
//     dev_step = round(2^PHASE_W * 0.35 / OSR)   (OSR=Fs/Rb)
//     例 PHASE_W=16,OSR=16 -> 1434.  做成端口, 改速率由PS重算 (自适应)
//   mod_in 由 premod_fir 提供 (满偏 ±(2^(MW-1)-1) = ±1.0);
//   若要纯NRZ(不达频谱模板)可直接给 ±满偏。
//
//   正弦表 sine_lut.mem (4096点, 有符号12bit, ad9361_freq.py --sinelut)
//============================================================================
module pcm_fm_mod #(
    parameter IQ_W    = 12,
    parameter MW      = 12,        // mod_in 位宽 (满偏=±(2^(MW-1)-1))
    parameter PHASE_W = 16,
    parameter LUT_AW  = 12,
    parameter LUT_N   = 4096
)(
    input                        clk,
    input                        rst_n,
    input                        sample_en,
    input      signed [MW-1:0]   mod_in,     // 成形后的调制信号 ±1.0
    input      [PHASE_W-1:0]     dev_step,   // 峰偏对应相位步进
    output reg signed [IQ_W-1:0] i_out,      // cos θ
    output reg signed [IQ_W-1:0] q_out,       // sin θ
    output      [PHASE_W-1:0] phase_debug,
    output signed [PHASE_W:0] inc_debug
);
    (* rom_style = "block" *) reg signed [IQ_W-1:0] sin_rom [0:LUT_N-1];
    initial $readmemh("sine_lut.mem", sin_rom);

    reg  [PHASE_W-1:0] phase;
    assign phase_debug = phase;
    // 相位增量 = mod_in * dev_step / 满偏(2^(MW-1))
    wire signed [MW+PHASE_W:0] prod = mod_in * $signed({1'b0, dev_step});
    wire signed [PHASE_W:0]    inc  = prod >>> (MW-1);
    assign inc_debug = inc;

    wire [LUT_AW-1:0]  idx_sin = phase[PHASE_W-1 -: LUT_AW];
    wire [LUT_AW-1:0]  idx_cos = idx_sin + (LUT_N/4);   // +90°


    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase <= {PHASE_W{1'b0}};
            i_out <= {IQ_W{1'b0}};
            q_out <= {IQ_W{1'b0}};
        end else if (sample_en) begin
            phase <= phase + inc[PHASE_W-1:0];
            i_out <= sin_rom[idx_cos];
            q_out <= sin_rom[idx_sin];
        end
    end
endmodule
