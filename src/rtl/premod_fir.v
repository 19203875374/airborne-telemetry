//============================================================================
// premod_fir.v  ——  PCM/FM 预调制滤波器 (IRIG-106, -3dB @ 0.7*Rb)
//   65 抽头线性相位低通, 系数内嵌为常量函数 coef_f (来自 premod_coef.mem, Q14)
//   归一化截止 0.7/OSR (OSR=16 -> 0.04375 cyc/sample), 随采样钟自动随 Rb 缩放
//   in/out: 有符号, 满偏 ±(2^(DW-1)-1) 代表 ±1.0
//   注: 系数用 case 常量函数而非 $readmemh+数组, 确保 Vivado 综合时真正加载
//       (并行 MAC 对数组用常量索引会使 $readmemh 失效)。
//============================================================================
module premod_fir #(
    parameter N_TAPS = 65,
    parameter CW     = 16,    // 系数位宽
    parameter FRAC   = 14,    // 系数小数位
    parameter DW     = 12     // 数据位宽
)(
    input                      clk,
    input                      rst_n,
    input                      sample_en,
    input      signed [DW-1:0] din,
    output reg signed [DW-1:0] dout
);
    function signed [15:0] coef_f; input integer i;
        case (i)
            0: coef_f = 16'h0008;   1: coef_f = 16'h000B;   2: coef_f = 16'h000E;
            3: coef_f = 16'h0012;   4: coef_f = 16'h0015;   5: coef_f = 16'h0018;
            6: coef_f = 16'h0018;   7: coef_f = 16'h0015;   8: coef_f = 16'h000E;
            9: coef_f = 16'h0002;  10: coef_f = 16'hFFF0;  11: coef_f = 16'hFFD9;
           12: coef_f = 16'hFFBD;  13: coef_f = 16'hFF9F;  14: coef_f = 16'hFF81;
           15: coef_f = 16'hFF69;  16: coef_f = 16'hFF59;  17: coef_f = 16'hFF57;
           18: coef_f = 16'hFF68;  19: coef_f = 16'hFF8F;  20: coef_f = 16'hFFCF;
           21: coef_f = 16'h002A;  22: coef_f = 16'h009E;  23: coef_f = 16'h012A;
           24: coef_f = 16'h01C7;  25: coef_f = 16'h0271;  26: coef_f = 16'h031E;
           27: coef_f = 16'h03C5;  28: coef_f = 16'h045F;  29: coef_f = 16'h04E1;
           30: coef_f = 16'h0544;  31: coef_f = 16'h0582;  32: coef_f = 16'h0596;
           33: coef_f = 16'h0582;  34: coef_f = 16'h0544;  35: coef_f = 16'h04E1;
           36: coef_f = 16'h045F;  37: coef_f = 16'h03C5;  38: coef_f = 16'h031E;
           39: coef_f = 16'h0271;  40: coef_f = 16'h01C7;  41: coef_f = 16'h012A;
           42: coef_f = 16'h009E;  43: coef_f = 16'h002A;  44: coef_f = 16'hFFCF;
           45: coef_f = 16'hFF8F;  46: coef_f = 16'hFF68;  47: coef_f = 16'hFF57;
           48: coef_f = 16'hFF59;  49: coef_f = 16'hFF69;  50: coef_f = 16'hFF81;
           51: coef_f = 16'hFF9F;  52: coef_f = 16'hFFBD;  53: coef_f = 16'hFFD9;
           54: coef_f = 16'hFFF0;  55: coef_f = 16'h0002;  56: coef_f = 16'h000E;
           57: coef_f = 16'h0015;  58: coef_f = 16'h0018;  59: coef_f = 16'h0018;
           60: coef_f = 16'h0015;  61: coef_f = 16'h0012;  62: coef_f = 16'h000E;
           63: coef_f = 16'h000B;  64: coef_f = 16'h0008;  default: coef_f = 0;
        endcase
    endfunction

    // ===== 转置型流水线 FIR =====
    // 同一 din 广播到所有抽头, 部分和经寄存器级联; 关键路径=1乘+1加 (高速)
    // 卷积结果与直接型一致, 仅多固定延迟。
    integer j;
    localparam ACW = DW + CW + 7;
    reg signed [ACW-1:0] acc [0:N_TAPS-1];
    wire signed [ACW-1:0] acc_sh = acc[0] >>> FRAC;
    localparam signed [DW-1:0] MAXV =  (1 <<< (DW-1)) - 1;
    localparam signed [DW-1:0] MINV = -(1 <<< (DW-1));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (j = 0; j < N_TAPS; j = j + 1) acc[j] <= {ACW{1'b0}};
            dout <= {DW{1'b0}};
        end else if (sample_en) begin
            acc[N_TAPS-1] <= din * coef_f(N_TAPS-1);
            for (j = N_TAPS-2; j >= 0; j = j - 1)
                acc[j] <= din * coef_f(j) + acc[j+1];
            // 输出: acc[0] 去系数小数位 + 饱和 (Gibbs过冲防回绕)
            if (acc_sh > MAXV)      dout <= MAXV;
            else if (acc_sh < MINV) dout <= MINV;
            else                    dout <= acc_sh[DW-1:0];
        end
    end
endmodule
