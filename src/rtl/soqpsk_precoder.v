//============================================================================
// soqpsk_precoder.v  ——  SOQPSK 三元预编码
//   二进制 b_i ∈{0,1}  ->  三元 α_i ∈{-1,0,+1}
//   α_i = (-1)^(i+1) * (2*b_{i-1}-1) * (b_i - b_{i-2})
//   (标准 SOQPSK 预编码, 产生约 25/50/25 的 -1/0/+1 分布)
//============================================================================
module soqpsk_precoder (
    input             clk,
    input             rst_n,
    input             bit_en,        // 1拍脉冲: 来一个新比特
    input             bit_in,        // b_i
    output reg signed [1:0] alpha,    // -1,0,+1
    output reg        alpha_vld      // 与 alpha 同拍有效
);
    reg b1, b2;        // b_{i-1}, b_{i-2}
    reg sgn_pos;       // (-1)^(i+1): i=0 -> 负, 故起始 sgn_pos=0

    // base = (2*b1-1)*(bit_in - b2) ∈ {-1,0,+1}
    function signed [1:0] base_f; input b1i, bi, b2i; begin
        case ({b1i, bi, b2i})
            3'b0_0_1, 3'b1_1_0: base_f =  2'sd1;
            3'b0_1_0, 3'b1_0_1: base_f = -2'sd1;
            default:            base_f =  2'sd0;
        endcase
    end endfunction

    wire signed [1:0] base = base_f(b1, bit_in, b2);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            b1<=0; b2<=0; sgn_pos<=0; alpha<=0; alpha_vld<=0;
        end else begin
            alpha_vld <= bit_en;
            if (bit_en) begin
                alpha   <= sgn_pos ? base : -base;   // (-1)^(i+1)
                sgn_pos <= ~sgn_pos;
                b2 <= b1; b1 <= bit_in;
            end
        end
    end
endmodule
