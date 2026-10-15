`timescale 1ns/1ps

// Coherent hard-decision BPSK/QPSK detector for AD9361 baseband I/Q samples.
// Carrier/timing recovery is expected from the configured signal generator and
// AD9361 clocking; integrate a Costas/timing loop for asynchronous field links.
module psk_demod #(
    parameter integer OSR = 8
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               enable,
    input  wire               qpsk_mode,
    input  wire signed [11:0] i_in,
    input  wire signed [11:0] q_in,
    input  wire               sample_valid,
    output reg  [1:0]         data_out,
    output reg                data_valid
);
    (* mark_debug = "true" *) reg [3:0] count;
    reg signed [19:0] i_acc;
    reg signed [19:0] q_acc;
    wire signed [19:0] i_sum = i_acc + i_in;
    wire signed [19:0] q_sum = q_acc + q_in;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 0; i_acc <= 0; q_acc <= 0;
            data_out <= 0; data_valid <= 0;
        end else begin
            data_valid <= 1'b0;
            if (!enable) begin
                count <= 0; i_acc <= 0; q_acc <= 0;
            end else if (sample_valid) begin
                if (count == OSR-1) begin
                    data_out[0] <= !i_sum[19];
                    data_out[1] <= qpsk_mode ? !q_sum[19] : 1'b0;
                    data_valid <= 1'b1;
                    count <= 0; i_acc <= 0; q_acc <= 0;
                end else begin
                    count <= count + 1'b1;
                    i_acc <= i_sum; q_acc <= q_sum;
                end
            end
        end
    end
endmodule
