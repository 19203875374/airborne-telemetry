//============================================================================
// fir_sym.v  —�??  RRC 成形/匹配 FIR (转置型流水线, 带饱�?)
//   系数内嵌为常量函�? coef_f (来自 rrc_coef.mem, β0.35/129抽头/Q14, OSR16/span8),
//   确保 Vivado 综合真正加载 (并行/常量索引会使 $readmemh 失效)�?
//   转置�?: �? din 广播 + 部分和寄存器级联, 关键路径=1�?1�? (高�??)�?
//   MEMFILE 参数保留仅为兼容旧例�?, 已不使用�?
//============================================================================
module fir_sym #(
    parameter MEMFILE = "rrc_coef.mem",   // 兼容占位, 未使�?
    parameter N_TAPS  = 129,
    parameter CW      = 16,
    parameter FRAC    = 14,
    parameter DW      = 12
)(
    input                      clk,
    input                      rst_n,
    input                      sample_en,
    input      signed [DW-1:0] din,
    output reg signed [DW-1:0] dout
);
    function signed [15:0] coef_f; input integer ii;
        case (ii)
              0: coef_f=16'h001F;
              1: coef_f=16'h0054;
              2: coef_f=16'h0084;
              3: coef_f=16'h00AC;
              4: coef_f=16'h00C7;
              5: coef_f=16'h00D3;
              6: coef_f=16'h00CF;
              7: coef_f=16'h00B8;
              8: coef_f=16'h008F;
              9: coef_f=16'h0057;
             10: coef_f=16'h0011;
             11: coef_f=16'hFFC3;
             12: coef_f=16'hFF71;
             13: coef_f=16'hFF22;
             14: coef_f=16'hFEDC;
             15: coef_f=16'hFEA5;
             16: coef_f=16'hFE83;
             17: coef_f=16'hFE7C;
             18: coef_f=16'hFE93;
             19: coef_f=16'hFECB;
             20: coef_f=16'hFF23;
             21: coef_f=16'hFF9A;
             22: coef_f=16'h002B;
             23: coef_f=16'h00CF;
             24: coef_f=16'h017F;
             25: coef_f=16'h0230;
             26: coef_f=16'h02D6;
             27: coef_f=16'h0365;
             28: coef_f=16'h03D1;
             29: coef_f=16'h040F;
             30: coef_f=16'h0413;
             31: coef_f=16'h03D8;
             32: coef_f=16'h0356;
             33: coef_f=16'h028E;
             34: coef_f=16'h0180;
             35: coef_f=16'h0035;
             36: coef_f=16'hFEB6;
             37: coef_f=16'hFD13;
             38: coef_f=16'hFB5E;
             39: coef_f=16'hF9AE;
             40: coef_f=16'hF81B;
             41: coef_f=16'hF6BF;
             42: coef_f=16'hF5B5;
             43: coef_f=16'hF516;
             44: coef_f=16'hF4FB;
             45: coef_f=16'hF579;
             46: coef_f=16'hF69F;
             47: coef_f=16'hF87A;
             48: coef_f=16'hFB0E;
             49: coef_f=16'hFE5A;
             50: coef_f=16'h0255;
             51: coef_f=16'h06F1;
             52: coef_f=16'h0C16;
             53: coef_f=16'h11A7;
             54: coef_f=16'h1784;
             55: coef_f=16'h1D85;
             56: coef_f=16'h2381;
             57: coef_f=16'h294C;
             58: coef_f=16'h2EBC;
             59: coef_f=16'h33A8;
             60: coef_f=16'h37E9;
             61: coef_f=16'h3B5D;
             62: coef_f=16'h3DE9;
             63: coef_f=16'h3F79;
             64: coef_f=16'h4000;
             65: coef_f=16'h3F79;
             66: coef_f=16'h3DE9;
             67: coef_f=16'h3B5D;
             68: coef_f=16'h37E9;
             69: coef_f=16'h33A8;
             70: coef_f=16'h2EBC;
             71: coef_f=16'h294C;
             72: coef_f=16'h2381;
             73: coef_f=16'h1D85;
             74: coef_f=16'h1784;
             75: coef_f=16'h11A7;
             76: coef_f=16'h0C16;
             77: coef_f=16'h06F1;
             78: coef_f=16'h0255;
             79: coef_f=16'hFE5A;
             80: coef_f=16'hFB0E;
             81: coef_f=16'hF87A;
             82: coef_f=16'hF69F;
             83: coef_f=16'hF579;
             84: coef_f=16'hF4FB;
             85: coef_f=16'hF516;
             86: coef_f=16'hF5B5;
             87: coef_f=16'hF6BF;
             88: coef_f=16'hF81B;
             89: coef_f=16'hF9AE;
             90: coef_f=16'hFB5E;
             91: coef_f=16'hFD13;
             92: coef_f=16'hFEB6;
             93: coef_f=16'h0035;
             94: coef_f=16'h0180;
             95: coef_f=16'h028E;
             96: coef_f=16'h0356;
             97: coef_f=16'h03D8;
             98: coef_f=16'h0413;
             99: coef_f=16'h040F;
            100: coef_f=16'h03D1;
            101: coef_f=16'h0365;
            102: coef_f=16'h02D6;
            103: coef_f=16'h0230;
            104: coef_f=16'h017F;
            105: coef_f=16'h00CF;
            106: coef_f=16'h002B;
            107: coef_f=16'hFF9A;
            108: coef_f=16'hFF23;
            109: coef_f=16'hFECB;
            110: coef_f=16'hFE93;
            111: coef_f=16'hFE7C;
            112: coef_f=16'hFE83;
            113: coef_f=16'hFEA5;
            114: coef_f=16'hFEDC;
            115: coef_f=16'hFF22;
            116: coef_f=16'hFF71;
            117: coef_f=16'hFFC3;
            118: coef_f=16'h0011;
            119: coef_f=16'h0057;
            120: coef_f=16'h008F;
            121: coef_f=16'h00B8;
            122: coef_f=16'h00CF;
            123: coef_f=16'h00D3;
            124: coef_f=16'h00C7;
            125: coef_f=16'h00AC;
            126: coef_f=16'h0084;
            127: coef_f=16'h0054;
            128: coef_f=16'h001F;
           default: coef_f=0;
        endcase
    endfunction

    integer j;
    localparam ACW = DW + CW + 8;
    reg signed [ACW-1:0] acc [0:N_TAPS-1];
    wire signed [ACW-1:0] acc_sh = acc[0] >>> FRAC;
    localparam signed [DW-1:0] MAXV =  (1<<<(DW-1))-1;
    localparam signed [DW-1:0] MINV = -(1<<<(DW-1));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (j=0;j<N_TAPS;j=j+1) acc[j] <= {ACW{1'b0}};
            dout <= {DW{1'b0}};
        end else if (sample_en) begin
            acc[N_TAPS-1] <= din * coef_f(N_TAPS-1);
            for (j=N_TAPS-2;j>=0;j=j-1)
                acc[j] <= din * coef_f(j) + acc[j+1];
            if      (acc_sh > MAXV) dout <= MAXV;
            else if (acc_sh < MINV) dout <= MINV;
            else                    dout <= acc_sh[DW-1:0];
        end
    end
endmodule
