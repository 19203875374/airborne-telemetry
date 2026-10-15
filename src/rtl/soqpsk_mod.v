//============================================================================
// soqpsk_mod.v  —�??  SOQPSK-TG 调制 (IRIG-106 Tier II, ARTM Tier I)
//   bit -> 三元预编�? α -> 冲激�? -> TG脉冲成形FIR -> 相位累加 -> NCO -> I/Q
//   h=1/2, 单符号相位步�? ±90°. 系数 soqpsk_pulse.mem (65抽头, 有符�?20bit).
//   正弦�? sine_lut.mem 复用 (�? PCM-FM 同一�?).
//============================================================================
module soqpsk_mod #(
    parameter IQ_W    = 12,
    parameter PHASE_W = 16,
    parameter NT = 129,
 //   parameter NT      = 65,     // 脉冲抽头�? (4符号 x OSR16 +1)
    parameter CW      = 20,     // 系数位宽
    parameter LUT_AW  = 12,
    parameter LUT_N   = 4096
)(
    input                        clk,
    input                        rst_n,
    input                        sample_en,   // Fs 节拍
    input                        bit_en,      // 比特节拍 (�? OSR �? sample_en �?�?)
    input                        bit_in,      // 待发比特
    output reg signed [IQ_W-1:0] i_out,
    output reg signed [IQ_W-1:0] q_out,
     // SOQPSK-TG调试输出
    output reg [PHASE_W-1:0]      phase_debug,
    output signed [CW+8-1:0]      acc_debug,
    output signed [1:0]           alpha_debug,
    output                        alpha_vld_debug
       
);


    // ---- 三元预编�? ----
    wire signed [1:0] alpha; wire alpha_vld;
    soqpsk_precoder u_pre (
        .clk(clk), .rst_n(rst_n), .bit_en(bit_en), .bit_in(bit_in),
        .alpha(alpha), .alpha_vld(alpha_vld));
    
        // 129-point SOQPSK-TG frequency-pulse coefficients.
    // Embedded constants are used because the transposed FIR accesses all
    // coefficients in parallel; Vivado cannot implement this as one BRAM ROM.
    function signed [19:0] coef_f;
        input integer ii;
        begin
            case (ii)
                0:   coef_f = 20'h00000;
                1:   coef_f = 20'h00000;
                2:   coef_f = 20'h00000;
                3:   coef_f = 20'h00000;
                4:   coef_f = 20'hFFFFF;
                5:   coef_f = 20'hFFFFF;
                6:   coef_f = 20'hFFFFF;
                7:   coef_f = 20'hFFFFF;
                8:   coef_f = 20'h00000;
                9:   coef_f = 20'h00000;
                10:  coef_f = 20'h00000;
                11:  coef_f = 20'h00000;
                12:  coef_f = 20'h00000;
                13:  coef_f = 20'h00000;
                14:  coef_f = 20'hFFFFF;
                15:  coef_f = 20'hFFFFE;
                16:  coef_f = 20'hFFFFC;
                17:  coef_f = 20'hFFFFA;
                18:  coef_f = 20'hFFFF7;
                19:  coef_f = 20'hFFFF4;
                20:  coef_f = 20'hFFFF1;
                21:  coef_f = 20'hFFFED;
                22:  coef_f = 20'hFFFE9;
                23:  coef_f = 20'hFFFE4;
                24:  coef_f = 20'hFFFE0;
                25:  coef_f = 20'hFFFDB;
                26:  coef_f = 20'hFFFD7;
                27:  coef_f = 20'hFFFD3;
                28:  coef_f = 20'hFFFD0;
                29:  coef_f = 20'hFFFCE;
                30:  coef_f = 20'hFFFCC;
                31:  coef_f = 20'hFFFCC;
                32:  coef_f = 20'hFFFCD;
                33:  coef_f = 20'hFFFCF;
                34:  coef_f = 20'hFFFD4;
                35:  coef_f = 20'hFFFDA;
                36:  coef_f = 20'hFFFE2;
                37:  coef_f = 20'hFFFED;
                38:  coef_f = 20'hFFFFA;
                39:  coef_f = 20'h0000A;
                40:  coef_f = 20'h0001B;
                41:  coef_f = 20'h00030;
                42:  coef_f = 20'h00047;
                43:  coef_f = 20'h00060;
                44:  coef_f = 20'h0007B;
                45:  coef_f = 20'h00098;
                46:  coef_f = 20'h000B7;
                47:  coef_f = 20'h000D8;
                48:  coef_f = 20'h000FA;
                49:  coef_f = 20'h0011C;
                50:  coef_f = 20'h0013F;
                51:  coef_f = 20'h00162;
                52:  coef_f = 20'h00185;
                53:  coef_f = 20'h001A7;
                54:  coef_f = 20'h001C8;
                55:  coef_f = 20'h001E7;
                56:  coef_f = 20'h00204;
                57:  coef_f = 20'h0021F;
                58:  coef_f = 20'h00237;
                59:  coef_f = 20'h0024C;
                60:  coef_f = 20'h0025D;
                61:  coef_f = 20'h0026B;
                62:  coef_f = 20'h00275;
                63:  coef_f = 20'h0027B;
                64:  coef_f = 20'h0027E;
                65:  coef_f = 20'h0027B;
                66:  coef_f = 20'h00275;
                67:  coef_f = 20'h0026B;
                68:  coef_f = 20'h0025D;
                69:  coef_f = 20'h0024C;
                70:  coef_f = 20'h00237;
                71:  coef_f = 20'h0021F;
                72:  coef_f = 20'h00204;
                73:  coef_f = 20'h001E7;
                74:  coef_f = 20'h001C8;
                75:  coef_f = 20'h001A7;
                76:  coef_f = 20'h00185;
                77:  coef_f = 20'h00162;
                78:  coef_f = 20'h0013F;
                79:  coef_f = 20'h0011C;
                80:  coef_f = 20'h000FA;
                81:  coef_f = 20'h000D8;
                82:  coef_f = 20'h000B7;
                83:  coef_f = 20'h00098;
                84:  coef_f = 20'h0007B;
                85:  coef_f = 20'h00060;
                86:  coef_f = 20'h00047;
                87:  coef_f = 20'h00030;
                88:  coef_f = 20'h0001B;
                89:  coef_f = 20'h0000A;
                90:  coef_f = 20'hFFFFA;
                91:  coef_f = 20'hFFFED;
                92:  coef_f = 20'hFFFE2;
                93:  coef_f = 20'hFFFDA;
                94:  coef_f = 20'hFFFD4;
                95:  coef_f = 20'hFFFCF;
                96:  coef_f = 20'hFFFCD;
                97:  coef_f = 20'hFFFCC;
                98:  coef_f = 20'hFFFCC;
                99:  coef_f = 20'hFFFCE;
                100: coef_f = 20'hFFFD0;
                101: coef_f = 20'hFFFD3;
                102: coef_f = 20'hFFFD7;
                103: coef_f = 20'hFFFDB;
                104: coef_f = 20'hFFFE0;
                105: coef_f = 20'hFFFE4;
                106: coef_f = 20'hFFFE9;
                107: coef_f = 20'hFFFED;
                108: coef_f = 20'hFFFF1;
                109: coef_f = 20'hFFFF4;
                110: coef_f = 20'hFFFF7;
                111: coef_f = 20'hFFFFA;
                112: coef_f = 20'hFFFFC;
                113: coef_f = 20'hFFFFE;
                114: coef_f = 20'hFFFFF;
                115: coef_f = 20'h00000;
                116: coef_f = 20'h00000;
                117: coef_f = 20'h00000;
                118: coef_f = 20'h00000;
                119: coef_f = 20'h00000;
                120: coef_f = 20'h00000;
                121: coef_f = 20'hFFFFF;
                122: coef_f = 20'hFFFFF;
                123: coef_f = 20'hFFFFF;
                124: coef_f = 20'hFFFFF;
                125: coef_f = 20'h00000;
                126: coef_f = 20'h00000;
                127: coef_f = 20'h00000;
                128: coef_f = 20'h00000;
                default: coef_f = 20'sd0;
            endcase
        end
    endfunction

    
    // ---- 冲激输入 (α 在比特拍注入, 其余�?0) ----
    wire signed [1:0] imp_in = alpha_vld ? alpha : 2'sd0;
    integer i;

    // ---- 转置型流水线 FIR -> 相位增量 (关键路径=1�?+1�?, 高�??) ----
    reg signed [CW+8-1:0] pacc [0:NT-1];
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i=0;i<NT;i=i+1) pacc[i] <= 0;
        end else if (sample_en) begin
              pacc[NT-1] <= imp_in * coef_f(NT-1);
            for (i=NT-2;i>=0;i=i-1)
              pacc[i] <= imp_in * coef_f(i) + pacc[i+1];
        end
    end
    wire signed [CW+8-1:0] acc = pacc[0];   // 相位增量

    // Source nets are declared before these assignments, avoiding accidental
    // one-bit implicit nets in strict Verilog compilation.
    assign alpha_debug     = alpha;
    assign alpha_vld_debug = alpha_vld;
    assign acc_debug       = acc;

    // ---- 相位累加 + NCO ----
    reg [PHASE_W-1:0] phase;
    wire [LUT_AW-1:0] idx_sin = phase[PHASE_W-1 -: LUT_AW];
    wire [LUT_AW-1:0] idx_cos = idx_sin + (LUT_N/4);
    (* rom_style="block" *) reg signed [IQ_W-1:0] sin_rom [0:LUT_N-1];
    initial $readmemh("sine_lut.mem", sin_rom);
///////////////添加与IQ对齐的相位调试信�?
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        phase       <= 0;
        phase_debug <= 0;
        i_out       <= 0;
        q_out       <= 0;
    end else if (sample_en) begin
        // 记录本次查表实际使用的相�?
        phase_debug <= phase;

        // 相位累加
        phase <= phase + acc[PHASE_W-1:0];

        // 当前phase用于本次正余弦查�?
        i_out <= sin_rom[idx_cos];
        q_out <= sin_rom[idx_sin];
    end
end
    
    
    
endmodule
