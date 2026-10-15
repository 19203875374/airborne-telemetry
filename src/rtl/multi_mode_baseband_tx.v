`timescale 1ns/1ps

// Dual-mode baseband transmitter running from the AD9361-derived sample clock.
// mode_sel=0 selects the PCM chain; pcm_mod_sel selects PCM-FM/SOQPSK-TG.
// mode_sel=1 selects the network chain; net_mod_sel selects BPSK/QPSK.
module multi_mode_baseband_tx #(
    parameter integer IQ_W       = 12,
    parameter integer PHASE_W    = 16,
//    parameter integer OSR_PCM    = 20,
    parameter integer OSR_PCM    = 16,
    parameter integer OSR_NET    = 16,
    parameter [PHASE_W-1:0] DEV_STEP = 16'd1434
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         tx_enable,
    input  wire                         mode_sel,
    input  wire                         pcm_mod_sel,
    input  wire                         net_mod_sel,
    output wire signed [IQ_W-1:0]       i_out,
    output wire signed [IQ_W-1:0]       q_out,
    output wire                         sample_valid,
    output wire                         pcm_bit_en,
    output wire                         net_sym_en,
    output wire [1:0]                   mode_active,
    output wire [1:0]                   psk_din_debug,
    output wire signed [IQ_W-1:0]       psk_i_imp_debug,
    output wire signed [IQ_W-1:0]       psk_q_imp_debug,
    output wire                         psk_sym_valid_debug,
    output wire [14:0]                  psk_prbs_debug,
    output wire [1:0]                   psk_din_used_debug
);
    localparam integer PCW = (OSR_PCM <= 2) ? 1 : $clog2(OSR_PCM);
    localparam integer NCW = (OSR_NET <= 2) ? 1 : $clog2(OSR_NET);

    reg [PCW-1:0] pcm_count;
    reg [NCW-1:0] net_count;
    reg [14:0] prbs_pcm;
    reg [14:0] prbs_net;
    reg [1:0]  active_mode;
    reg [7:0]  mute_count;

    // Internal branch code is used only after the two-level system selection:
    // 00 PCM-FM, 01 SOQPSK-TG, 10 BPSK, 11 QPSK.
    wire [1:0] requested_mode = mode_sel ? {1'b1, net_mod_sel}
                                               : {1'b0, pcm_mod_sel};

    assign pcm_bit_en = (pcm_count == OSR_PCM-1);
    assign net_sym_en = (net_count == OSR_NET-1);
    assign mode_active = active_mode;
    assign psk_din_debug = prbs_net[1:0];
    assign psk_din_used_debug = psk_din_used;
    assign psk_i_imp_debug = psk_i_imp;
    assign psk_q_imp_debug = psk_q_imp;
    assign psk_sym_valid_debug = net_sym_en && ((active_mode == 2'b10) || (active_mode == 2'b11));
    assign psk_prbs_debug = prbs_net;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pcm_count   <= {PCW{1'b0}};
            net_count   <= {NCW{1'b0}};
            prbs_pcm    <= 15'h7FFF;
            prbs_net    <= 15'h5A35;
            active_mode <= 2'b00;
            mute_count  <= 8'd255;
        end else begin
            pcm_count <= pcm_bit_en ? {PCW{1'b0}} : pcm_count + 1'b1;
            net_count <= net_sym_en ? {NCW{1'b0}} : net_count + 1'b1;

            // PRBS15: x^15 + x^14 + 1. The two chains are intentionally
            // independent so PCM and network modes have repeatable stimuli.
            if (pcm_bit_en)
                prbs_pcm <= {prbs_pcm[13:0], prbs_pcm[14] ^ prbs_pcm[13]};
//            if (pcm_bit_en)
//                prbs_soqpsk <= { prbs_soqpsk[21:0], prbs_soqpsk[22] ^ prbs_soqpsk[17] };
            if (net_sym_en)
                prbs_net <= {prbs_net[12:0],
                             prbs_net[14] ^ prbs_net[13],
                             prbs_net[13] ^ prbs_net[12]};

            // Mute 128 samples after a mode change. This covers the 65-tap
            // shaping-filter tail and prevents a switching transient at RF.         
            if (requested_mode != active_mode) begin
                active_mode <= requested_mode;
                mute_count  <= 8'd128;
            end else if (mute_count != 0) begin
                mute_count <= mute_count - 1'b1;
            end
        end
    end

    wire signed [IQ_W-1:0] fm_i;
    wire signed [IQ_W-1:0] fm_q;
    wire signed [IQ_W-1:0] soqpsk_i;
    wire signed [IQ_W-1:0] soqpsk_q;
    wire signed [IQ_W-1:0] psk_i;
    wire signed [IQ_W-1:0] psk_q;
    wire signed [IQ_W-1:0] psk_i_imp;
    wire signed [IQ_W-1:0] psk_q_imp;
    wire [1:0] psk_din_used;

    pcm_fm_top #(
        .IQ_W(IQ_W),
        .PHASE_W(PHASE_W)
    ) u_pcm_fm (
        .clk(clk),
        .rst_n(rst_n),
        .sample_en(1'b1),
        .data_level(prbs_pcm[0]),
        .polarity(1'b0),
        .dev_step(DEV_STEP),
        .i_out(fm_i),
        .q_out(fm_q),
        .phase_debug(),
        .inc_debug(),
        .nrz_debug(),
        .shaped_debug()
    );

    soqpsk_mod #(
        .IQ_W(IQ_W),
        .PHASE_W(PHASE_W),
        .NT(129)
    ) u_soqpsk (
        .clk(clk),
        .rst_n(rst_n),        
        .sample_en(1'b1),
        .bit_en(pcm_bit_en),
//        .bit_in(prbs_soqpsk[0]),
      .bit_in(prbs_pcm[0]),
        .i_out(soqpsk_i),
        .q_out(soqpsk_q),
        .phase_debug(),
        .acc_debug(),
        .alpha_debug(),
        .alpha_vld_debug()
    );

    // A single PSK modulator is shared by BPSK and QPSK. In BPSK mode
    // q_imp is zero; in QPSK mode both input bits map to Gray-coded I/Q.
    psk_mod #(
        .IQ_W(IQ_W)
    ) u_psk (
        .clk(clk),
        .rst_n(rst_n),
        .sample_en(1'b1),
        .sym_en(net_sym_en),
        .mode(active_mode == 2'b11),
        .din(prbs_net[1:0]),
        .i_out(psk_i), .q_out(psk_q),
        .i_imp_debug(psk_i_imp), .q_imp_debug(psk_q_imp),
        .din_used_debug(psk_din_used)
    );

    reg signed [IQ_W-1:0] selected_i;
    reg signed [IQ_W-1:0] selected_q;
    always @* begin
        case (active_mode)
            2'b00: begin selected_i = fm_i;     selected_q = fm_q;     end
            2'b01: begin selected_i = soqpsk_i; selected_q = soqpsk_q; end
            2'b10: begin selected_i = psk_i;    selected_q = psk_q;    end
            default: begin selected_i = psk_i;  selected_q = psk_q;    end
        endcase
    end

    assign sample_valid = rst_n;
    assign i_out = (tx_enable && (mute_count == 0)) ? selected_i : {IQ_W{1'b0}};
    assign q_out = (tx_enable && (mute_count == 0)) ? selected_q : {IQ_W{1'b0}};
endmodule
