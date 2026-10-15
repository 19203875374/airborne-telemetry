module pcm_fm_top #(
    parameter IQ_W    = 12,
    parameter PHASE_W = 16
)(
    input                         clk,
    input                         rst_n,
    input                         sample_en,
    input                         data_level,
    input                         polarity,
    input      [PHASE_W-1:0]      dev_step,

    output signed [IQ_W-1:0]      i_out,
    output signed [IQ_W-1:0]      q_out,
    output        [PHASE_W-1:0]   phase_debug,
    output signed [PHASE_W:0]     inc_debug,

    output signed [IQ_W-1:0]      nrz_debug,
    output signed [IQ_W-1:0]      shaped_debug
);

    localparam signed [IQ_W-1:0] FS =
        (1 <<< (IQ_W-1)) - 1;

    wire lvl;
    wire signed [IQ_W-1:0] nrz;
    wire signed [IQ_W-1:0] shaped;

    assign lvl = data_level ^ polarity;
    assign nrz = lvl ? FS : -FS;

    assign nrz_debug    = nrz;
    assign shaped_debug = shaped;

    premod_fir #(
        .DW(IQ_W)
    ) u_fir (
        .clk(clk),
        .rst_n(rst_n),
        .sample_en(sample_en),
        .din(nrz),
        .dout(shaped)
    );

    pcm_fm_mod #(
        .IQ_W(IQ_W),
        .MW(IQ_W),
        .PHASE_W(PHASE_W)
    ) u_mod (
        .clk(clk),
        .rst_n(rst_n),
        .sample_en(sample_en),
        .mod_in(shaped),
        .dev_step(dev_step),
        .i_out(i_out),
        .q_out(q_out),
        .phase_debug(phase_debug),
        .inc_debug(inc_debug)
    );

endmodule