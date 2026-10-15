`timescale 1ns/1ps

// AD9361 initialization and independent FDD RX/TX LO updates.
module ad9361_spi_ctrl (
    input wire rst_n, input wire clk,
    input wire [11:0] tx_freq_index, input wire [9:0] rx_freq_index,
    input wire freq_req_toggle, input wire tx_enable_req,
    input wire [1:0] mode_in,   // per-mode TX filter profile: 00 PCM-FM / 01 SOQPSK / 10 BPSK / 11 QPSK
    output wire [7:0] rfpll_status, output wire init_done,
    output wire [11:0] debug_init_index, output wire [7:0] debug_spi_dout,
    output reg [7:0] debug_tx271, output reg [7:0] debug_tx287,
    output reg [7:0] debug_reg002, output reg [7:0] debug_reg014,
    output reg runtime_done_latched, output reg runtime_error_latched,
    output reg freq_busy, output reg freq_done, output reg freq_error,
    output wire sclk, output wire sdi, output wire csb, input wire sdo
);
    `include "ad9361_lut.v"
    localparam [11:0] INIT_LAST = 12'd2574;
    (* rom_style="block" *) reg [39:0] tx_rom [0:2000];
    (* rom_style="block" *) reg [39:0] rx_rom [0:500];
    initial begin
        $readmemh("freq_lut_tx.mem", tx_rom);
        $readmemh("freq_lut_rx.mem", rx_rom);
    end

    // ---- Per-mode TX filter tables (AD9361 TX FIR + BBF + secondary filter) ----
    // 4 profiles x 128 taps, 16-bit signed.  index = {mode[1:0], tap[6:0]} = mode*128 + tap.
    // The AD9361 TX 128-tap FIR is a fixed half-band interpolator at 30.72 MSPS:
    // its coefficients are bandwidth-independent and identical across all 4 modes
    // (verified: the 3 Filter Wizard .ftr outputs share the same 0x061/0x062 bytes).
    // Only the analog BBF tune divider (0x0d6/0x0d7) and secondary filter cal
    // (0x0d0..0x0d2) actually set the per-mode passband; those live in tx_filt_params.
    (* rom_style="block" *) reg [15:0] tx_fir_coeff [0:511];
    initial $readmemh("tx_fir_coeff.mem", tx_fir_coeff);

    // Per-mode scalar settings (6 bytes each), indexed by mode[1:0].
    //   gain_en        : 0x065 TX FIR clock-enable + gain byte (0xfa = clock on)
    //   bbf_lo / bbf_hi: 0x0d6 / 0x0d7 TX BBF tune divider [7:0] / [8]
    //   sec_cap/res/bias: 0x0d2 / 0x0d1 / 0x0d0 TX secondary filter cal
    // Values are the CURRENT 2.25 MHz profile as PLACEHOLDERS; replace per mode.
    reg [7:0] tx_fir_gain_en [0:3];
    reg [7:0] tx_bbf_lo      [0:3];
    reg [7:0] tx_bbf_hi      [0:3];
    reg [7:0] tx_sec_cap     [0:3];
    reg [7:0] tx_sec_res     [0:3];
    reg [7:0] tx_sec_bias    [0:3];
    initial begin : tx_filt_params
        // mode 0 = PCM-FM  (Real 2.6 MHz / RF 5.2): BBF 0x1b, sec 0x31/0x04/0x59
        tx_fir_gain_en[0]=8'hfa; tx_bbf_lo[0]=8'h1b; tx_bbf_hi[0]=8'h1e; tx_sec_cap[0]=8'h31; tx_sec_res[0]=8'h04; tx_sec_bias[0]=8'h59;
        // mode 1 = SOQPSK   (Real 0.75 MHz / RF 1.5): BBF 0x5b, sec 0x29/0x01/0x59
        tx_fir_gain_en[1]=8'hfa; tx_bbf_lo[1]=8'h5b; tx_bbf_hi[1]=8'h1e; tx_sec_cap[1]=8'h29; tx_sec_res[1]=8'h01; tx_sec_bias[1]=8'h59;
        // mode 2 = BPSK     (Real 1.3 MHz / RF 2.6): BBF 0x35, sec 0x31/0x03/0x59
        tx_fir_gain_en[2]=8'hfa; tx_bbf_lo[2]=8'h35; tx_bbf_hi[2]=8'h1e; tx_sec_cap[2]=8'h31; tx_sec_res[2]=8'h03; tx_sec_bias[2]=8'h59;
        // mode 3 = QPSK     (Real 1.3 MHz / RF 2.6): BBF 0x35, sec 0x31/0x03/0x59
        tx_fir_gain_en[3]=8'hfa; tx_bbf_lo[3]=8'h35; tx_bbf_hi[3]=8'h1e; tx_sec_cap[3]=8'h31; tx_sec_res[3]=8'h03; tx_sec_bias[3]=8'h59;
    end
    reg [11:0] tx_index_meta, tx_index_sync, last_tx_index;
    reg [9:0]  rx_index_meta, rx_index_sync, last_rx_index;
    wire [11:0] tx_index = tx_index_sync <= 2000 ? tx_index_sync : 12'd2000;
    wire [9:0]  rx_index = rx_index_sync <= 500 ? rx_index_sync : 10'd500;

    reg req_meta, req_sync, req_seen, req_armed;
    reg tx_enable_meta, tx_enable_sync, last_tx_enable, tx_req_armed;
    reg [1:0] mode_meta, mode_sync;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            req_meta<=0; req_sync<=0;
            tx_enable_meta<=0; tx_enable_sync<=0;
            tx_index_meta<=0; tx_index_sync<=0;
            rx_index_meta<=0; rx_index_sync<=0;
            mode_meta<=0; mode_sync<=0;
        end else begin
            req_meta<=freq_req_toggle; req_sync<=req_meta;
            tx_enable_meta<=tx_enable_req; tx_enable_sync<=tx_enable_meta;
            tx_index_meta<=tx_freq_index; tx_index_sync<=tx_index_meta;
            rx_index_meta<=rx_freq_index; rx_index_sync<=rx_index_meta;
            mode_meta<=mode_in; mode_sync<=mode_meta;
        end

    wire [7:0] spi_dout; wire spi_dout_en, spi_busy;
    reg [4:0] state; reg [11:0] init_index; reg [18:0] cmd;
    reg [9:0] addr; reg [7:0] din; reg din_en, wr_rdn;
    reg [31:0] wait_cnt; reg [7:0] rfpll_lock;
    reg runtime_mode; reg runtime_tx_switch; reg runtime_tx_target;
    reg runtime_failed; reg [6:0] runtime_step;
    reg [39:0] runtime_tx_word, runtime_rx_word;
    reg [15:0] lock_poll_count;
    reg [5:0] tx_quad_a3_low;
    reg [18:0] init_cmd_merged;
    // TX filter per-mode switch state
    reg [1:0] last_mode, filt_target_mode;
    reg filt_first_done;
    reg runtime_filt;
    reg [11:0] filt_step;
    reg [18:0] filt_cmd_merged;

always @* begin
    init_cmd_merged = cmd_data(init_index);
    // At init index 2522, preserve register 0x0A3[5:0] and replace only bits [7:6].
    if (init_index == 12'd2522)
        init_cmd_merged[5:0] = tx_quad_a3_low;
end

    // ---- TX filter reprogram command generator (per-mode FIR + BBF + secondary cal) ----
    // filt_step map (see FSM for step-advance / readback / settle logic):
    //   0        = 0x014=0x05  ENSM ALERT (mute TX)
    //   1        = 0x065 gain_en (enable FIR clock + gain)
    //   2..769   = 128 taps x 6 writes: 0x060 addr, 0x061 lo, 0x062 hi, 0x065=0xfe wr, 0x064 dly x2
    //   770      = 0x065=0xf8  disable FIR clock
    //   771..772 = 0x0d6/0x0d7 BBF tune divider
    //   773      = 0x0ca=0x22  enable TX filter tuner
    //   774      = 0x016=0x40  start TX filter tune
    //   775      = read 0x016  poll CALDONE bit 6
    //   776      = 0x0ca=0x26  disable TX filter tuner
    //   777..779 = 0x0d2/0x0d1/0x0d0 secondary filter cal
    //   780      = 0x014=0x65  ENSM FDD TX (re-enable)
    //   781      = done marker
    always @* begin : tx_filt_cmd
        integer ft, ftap;
        ft = filt_step;
        ftap = (ft - 12'd2) / 6;
        if (ft >= 12'd2 && ft <= 12'd769) begin
            case ((ft - 12'd2) % 6)
                0: filt_cmd_merged = {1'b1, 10'h060, {1'b0, ftap[6:0]}};
                1: filt_cmd_merged = {1'b1, 10'h061, tx_fir_coeff[{filt_target_mode, ftap[6:0]}][7:0]};
                2: filt_cmd_merged = {1'b1, 10'h062, tx_fir_coeff[{filt_target_mode, ftap[6:0]}][15:8]};
                3: filt_cmd_merged = {1'b1, 10'h065, 8'hfe};
                default: filt_cmd_merged = {1'b1, 10'h064, 8'h00};
            endcase
        end else begin
            case (ft)
                12'd0:   filt_cmd_merged = {1'b1, 10'h014, 8'h05};
                12'd1:   filt_cmd_merged = {1'b1, 10'h065, tx_fir_gain_en[filt_target_mode]};
                12'd770: filt_cmd_merged = {1'b1, 10'h065, 8'hf8};
                12'd771: filt_cmd_merged = {1'b1, 10'h0d6, tx_bbf_lo[filt_target_mode]};
                12'd772: filt_cmd_merged = {1'b1, 10'h0d7, tx_bbf_hi[filt_target_mode]};
                12'd773: filt_cmd_merged = {1'b1, 10'h0ca, 8'h22};
                12'd774: filt_cmd_merged = {1'b1, 10'h016, 8'h40};
                12'd775: filt_cmd_merged = {1'b0, 10'h016, 8'h00};
                12'd776: filt_cmd_merged = {1'b1, 10'h0ca, 8'h26};
                12'd777: filt_cmd_merged = {1'b1, 10'h0d2, tx_sec_cap[filt_target_mode]};
                12'd778: filt_cmd_merged = {1'b1, 10'h0d1, tx_sec_res[filt_target_mode]};
                12'd779: filt_cmd_merged = {1'b1, 10'h0d0, tx_sec_bias[filt_target_mode]};
                12'd780: filt_cmd_merged = {1'b1, 10'h014, 8'h65};
                default: filt_cmd_merged = {1'b1, 10'h014, 8'h05};
            endcase
        end
    end

    function [18:0] runtime_cmd;
        input [6:0] step;
        input [39:0] tx_word;
        input [39:0] rx_word;
        input tx_on;
        begin
            case(step)
                0:  runtime_cmd={1'b1,10'h014,8'h05}; // Force ENSM ALERT.

                // ---- TX synthesizer retune: full VCO recalibration ----
                // Reproduce the init table's VCO cal setup + CP cal + VCO ALC
                // sequence (index 1616..1669) verbatim, including the VCO LDO
                // enable, VCO power-down TCF, dual-synth and ENSM-FDD writes that
                // the AD9361 needs re-armed after the ALERT state. A bare
                // integer-word write does NOT re-select the VCO band, so the LO
                // stays on the init band and unlocks once the new LO leaves it.
                1:  runtime_cmd={1'b1,10'h288,8'h0b};  // Enable Tx VCO LDO.
                2:  runtime_cmd={1'b1,10'h286,8'h02};  // VCO power down TCF.
                3:  runtime_cmd={1'b1,10'h289,8'h8e};  // VCO cal length.
                4:  runtime_cmd={1'b1,10'h27b,8'h80};  // Enable TX VCO cal.
                5:  runtime_cmd={1'b1,10'h283,8'h0d};  // Prescaler bias.
                6:  runtime_cmd={1'b1,10'h27d,8'h00};  // Clear half VCO cal clock.
                7:  runtime_cmd={1'b1,10'h015,8'h04};  // Dual synth mode.
                8:  runtime_cmd={1'b1,10'h013,8'h01};  // ENSM FDD mode.
                9:  runtime_cmd={1'b1,10'h27d,8'h04};  // Start TX CP cal.
                10: runtime_cmd={1'b0,10'h284,8'h00};  // TX CP cal CALDONE: bit 7.
                11: runtime_cmd={1'b1,10'h27a,8'h4a};  // VCO output level.
                12: runtime_cmd={1'b1,10'h279,8'hc1};  // Init ALC + varactor.
                13: runtime_cmd={1'b1,10'h282,8'h0e};  // VCO bias Tcf/ref.
                14: runtime_cmd={1'b1,10'h278,8'h78};  // VCO cal offset.
                15: runtime_cmd={1'b1,10'h285,8'h00};  // VCO cal ref Tcf.
                16: runtime_cmd={1'b1,10'h291,8'h0b};  // VCO varactor ref.
                17: runtime_cmd={1'b1,10'h290,8'h70};  // Varactor ref Tcf+offset.
                18: runtime_cmd={1'b1,10'h27b,8'h8d};  // Icp (+ VCO cal enable bit7).
                19: runtime_cmd={1'b1,10'h27e,8'hc3};  // Loop filter C2/C1.
                20: runtime_cmd={1'b1,10'h27f,8'hef};  // Loop filter R1/C3.
                21: runtime_cmd={1'b1,10'h280,8'h0b};  // Loop filter R3.
                22: runtime_cmd={1'b1,10'h273,tx_word[7:0]};      // frac[7:0]
                23: runtime_cmd={1'b1,10'h274,tx_word[15:8]};     // frac[15:8]
                24: runtime_cmd={1'b1,10'h275,tx_word[23:16]};    // frac[22:16]
                25: runtime_cmd={1'b1,10'h272,tx_word[31:24]};    // int[10:8]
                26: runtime_cmd={1'b1,10'h271,tx_word[39:32]};    // int[7:0] -> starts VCO cal.
                27: runtime_cmd={1'b1,10'h005,8'h11};          // LO divider /4.
                28: runtime_cmd={1'b0,10'h273,8'h00};
                29: runtime_cmd={1'b0,10'h274,8'h00};
                30: runtime_cmd={1'b0,10'h275,8'h00};
                31: runtime_cmd={1'b0,10'h272,8'h00};
                32: runtime_cmd={1'b0,10'h271,8'h00};
                33: runtime_cmd={1'b0,10'h287,8'h00};          // TX RFPLL lock: bit 1.

                // ---- RX synthesizer retune ----
                34: runtime_cmd={1'b1,10'h248,8'h0b};  // Enable Rx VCO LDO.
                35: runtime_cmd={1'b1,10'h246,8'h02};  // VCO power down TCF.
                36: runtime_cmd={1'b1,10'h249,8'h8e};  // RX VCO cal length.
                37: runtime_cmd={1'b1,10'h23b,8'h80};  // Enable RX VCO cal.
                38: runtime_cmd={1'b1,10'h243,8'h0d};  // RX prescaler bias.
                39: runtime_cmd={1'b1,10'h23d,8'h00};  // Clear half VCO cal clock.
                40: runtime_cmd={1'b1,10'h23d,8'h04};  // Start RX CP cal.
                41: runtime_cmd={1'b0,10'h244,8'h00};  // RX CP cal CALDONE: bit 7.
                42: runtime_cmd={1'b1,10'h23a,8'h4a};
                43: runtime_cmd={1'b1,10'h239,8'hc1};
                44: runtime_cmd={1'b1,10'h242,8'h0e};
                45: runtime_cmd={1'b1,10'h238,8'h78};
                46: runtime_cmd={1'b1,10'h245,8'h00};
                47: runtime_cmd={1'b1,10'h251,8'h0b};
                48: runtime_cmd={1'b1,10'h250,8'h70};
                49: runtime_cmd={1'b1,10'h23b,8'h90};  // Icp (+ VCO cal enable bit7).
                50: runtime_cmd={1'b1,10'h23e,8'hc3};
                51: runtime_cmd={1'b1,10'h23f,8'hef};
                52: runtime_cmd={1'b1,10'h240,8'h0b};
                53: runtime_cmd={1'b1,10'h233,rx_word[7:0]};
                54: runtime_cmd={1'b1,10'h234,rx_word[15:8]};
                55: runtime_cmd={1'b1,10'h235,rx_word[23:16]};
                56: runtime_cmd={1'b1,10'h232,rx_word[31:24]};
                57: runtime_cmd={1'b1,10'h231,rx_word[39:32]};    // starts RX VCO cal.
                58: runtime_cmd={1'b1,10'h005,8'h11};
                59: runtime_cmd={1'b0,10'h233,8'h00};
                60: runtime_cmd={1'b0,10'h234,8'h00};
                61: runtime_cmd={1'b0,10'h235,8'h00};
                62: runtime_cmd={1'b0,10'h232,8'h00};
                63: runtime_cmd={1'b0,10'h231,8'h00};
                64: runtime_cmd={1'b0,10'h247,8'h00};          // RX RFPLL lock: bit 1.

                // Restore and verify the requested ENSM state.
                65: runtime_cmd={1'b1,10'h014,tx_on ? 8'h65 : 8'h05};
                66: runtime_cmd={1'b0,10'h014,8'h00};
                default: runtime_cmd={1'b0,10'h014,8'h00};
            endcase
        end
    endfunction

    function [18:0] tx_switch_cmd;
        input [6:0] step;
        input tx_on;
        begin
            case(step)
                0: tx_switch_cmd={1'b1,10'h014,tx_on ? 8'h65 : 8'h05};
                1: tx_switch_cmd={1'b0,10'h014,8'h00};
                default: tx_switch_cmd={1'b0,10'h014,8'h00};
            endcase
        end
    endfunction
    assign rfpll_status=rfpll_lock;
    assign debug_init_index=init_index;
    assign debug_spi_dout=spi_dout;
    assign init_done=(init_index==INIT_LAST)&&(state==5)&&!runtime_mode;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=0; init_index<=0; cmd<=0; addr<=0; din<=0; din_en<=0; wr_rdn<=0;
            wait_cnt<=0; rfpll_lock<=0; req_seen<=0; req_armed<=0;
            last_tx_index<=0; last_rx_index<=0;
            last_tx_enable<=1'b1; tx_req_armed<=1'b0;
            runtime_mode<=0; runtime_tx_switch<=0; runtime_tx_target<=1'b1;
            runtime_failed<=0;
            runtime_step<=0; runtime_tx_word<=0; runtime_rx_word<=0; lock_poll_count<=0;
            debug_tx271<=0; debug_tx287<=0;
            debug_reg002<=0; debug_reg014<=0;
            runtime_done_latched<=0; runtime_error_latched<=0;
            freq_busy<=0; freq_done<=0; freq_error<=0;
            runtime_filt<=0; filt_step<=0; filt_target_mode<=0;
            filt_first_done<=0; last_mode<=0;
            tx_quad_a3_low <= 6'd0;
        end else begin
            freq_done<=0;
            case(state)
                0: begin
                    cmd<=runtime_filt
                        ? filt_cmd_merged
                        : (runtime_mode
                            ? (runtime_tx_switch
                                ? tx_switch_cmd(runtime_step,runtime_tx_target)
                                : runtime_cmd(runtime_step,runtime_tx_word,runtime_rx_word,
                                              runtime_tx_target))
                            : init_cmd_merged);
                    state<=1;
                end
                1: if(!spi_busy) begin state<=2; wr_rdn<=cmd[18]; addr<=cmd[17:8]; din<=cmd[7:0]; din_en<=1; end
                2: if(spi_busy) begin state<=3; din_en<=0; end
                3: state<=wr_rdn?5:4;
                4: if(spi_dout_en) begin
                    if(runtime_filt) begin
                        // The only read in the filt sequence is step 775 (TX filter
                        // tune CALDONE): poll 0x016 bit 6 until it clears.
                        if(filt_step == 12'd775) begin
                            if(!spi_dout[6]) begin
                                lock_poll_count<=16'd0;
                                filt_step<=12'd776;
                                state<=5;
                            end else if(lock_poll_count==16'hffff) begin
                                runtime_error_latched<=1'b1;
                                lock_poll_count<=16'd0;
                                filt_step<=12'd776;
                                state<=5;
                            end else begin
                                lock_poll_count<=lock_poll_count+1'b1;
                                state<=0;
                            end
                        end else begin
                            runtime_error_latched<=1'b1;
                            state<=5;
                        end
                    end else if(runtime_mode) begin
                        if(runtime_tx_switch) begin
                            if(runtime_step==1) begin
                                debug_reg014<=spi_dout;
                                // 0x014[D2] is a self-clearing Force ALERT command.
                                runtime_failed<=runtime_failed ||
                                    ((spi_dout & 8'hfb) !=
                                     ((runtime_tx_target ? 8'h65 : 8'h05) & 8'hfb));
                                runtime_step<=5'd2;
                                state<=5;
                            end else begin
                                runtime_failed<=1'b1;
                                runtime_step<=5'd2;
                                state<=5;
                            end
                        end else if(runtime_step>=28 && runtime_step<=32) begin
                            // Readback of 0x273..0x271 is diagnostic only: do NOT
                            // abort on a mismatch. Reserved bits and in-progress
                            // VCO-cal transients can make the readback differ from
                            // the programmed word, and an early jump to ENSM-restore
                            // would corrupt a still-running calibration. The lock
                            // poll (step 33) is the authoritative success test.
                            if (runtime_step==32) debug_tx271 <= spi_dout;
                            runtime_step <= runtime_step + 1'b1;
                            state <= 0;
                        end else if(runtime_step>=59 && runtime_step<=63) begin
                            // RX synth readback is diagnostic only (see TX note above).
                            runtime_step <= runtime_step + 1'b1;
                            state <= 0;
                        end else if(runtime_step==10 || runtime_step==41) begin
                            // CP cal CALDONE poll (0x284/0x244 bit 7), mirroring
                            // init table index 1631/1633.
                            if(spi_dout[7] || (lock_poll_count==16'hffff)) begin
                                lock_poll_count<=0;
                                runtime_step<=runtime_step+1'b1;
                                state<=0;
                            end else begin
                                lock_poll_count<=lock_poll_count+1'b1;
                                state<=0;
                            end
                        end else if(runtime_step==33 || runtime_step==64) begin
                            rfpll_lock<=spi_dout;
                            if (runtime_step == 33) debug_tx287 <= spi_dout;
                            if(spi_dout[1]) begin
                                lock_poll_count<=0;
                                runtime_step<=runtime_step+1'b1;
                                state<=0;
                            end else if(lock_poll_count==16'hffff) begin
                                // Always restore the requested ENSM state after a lock timeout.
                                runtime_failed<=1'b1;
                                rfpll_lock<=0;
                                lock_poll_count<=0;
                                runtime_step<=7'd65;
                                state<=0;
                            end else begin
                                lock_poll_count<=lock_poll_count+1'b1;
                                state<=0;
                            end
                        end else if(runtime_step==66) begin
                            debug_reg014<=spi_dout;
                            runtime_failed<=runtime_failed ||
                                ((spi_dout & 8'hfb) !=
                                 ((runtime_tx_target ? 8'h65 : 8'h05) & 8'hfb));
                            runtime_step<=7'd67;
                            state<=5;
                        end
                    end 
                    else begin
                        case(init_index)
                            30: state<=spi_dout[7]?5:0; // BBPLL lock.
                            // The generated script reads bit 7 after starting
                            // each RF charge-pump calibration.
                            1631,1633: begin
                                if(spi_dout[7]) begin
                                    lock_poll_count<=0;
                                    state<=5;
                                end else if(lock_poll_count==16'd4095) begin
                                    // Avoid a permanent initialization hang while
                                    // still allowing about 200 ms for calibration.
                                    lock_poll_count<=0;
                                    state<=5;
                                end else begin
                                    lock_poll_count<=lock_poll_count+1'b1;
                                    state<=0;
                                end
                            end
                            1668: begin rfpll_lock<=spi_dout; state<=spi_dout[1]?5:0; end
                            1669: begin rfpll_lock<=spi_dout; state<=spi_dout[1]?5:0; end
                            2457: state<=!spi_dout[7]?5:0; // RX filter tune.
                            2464: state<=!spi_dout[6]?5:0; // TX filter tune.
                            2535: state<=!spi_dout[0]?5:0; // Baseband DC calibration.
                            2543: state<=!spi_dout[1]?5:0; // RF DC calibration.
                            2545: state<=!spi_dout[4]?5:0; // TX quadrature calibration.
                            2572: begin
                                debug_reg002<=spi_dout;
                              if (spi_dout == 8'hce) begin
                                    state<=5;
                                end else begin
                                    runtime_error_latched<=1'b1;
                                    state<=5;
                                end
                            end
                            2573: begin
                                debug_reg014<=spi_dout;
                                // Force ALERT (D2) is a self-clearing command bit.
                                if((spi_dout & 8'hfb)==(8'h65 & 8'hfb)) begin
                                    state<=5;
                                end else begin
                                    runtime_error_latched<=1'b1;
                                    state<=5;
                                end
                            end
                            2520: begin
                            tx_quad_a3_low <= spi_dout[5:0];
                            state <= 5;
                            end
                            default: state<=5;
                        endcase
                    end
                end
                5: if(runtime_filt) begin
                    if(filt_step == 12'd0 || filt_step == 12'd780) begin
                        // ENSM transition settle time (UG-570), same wait as runtime ENSM ops.
                        if(wait_cnt!=32'd6250) wait_cnt<=wait_cnt+1'b1;
                        else begin
                            wait_cnt<=0;
                            filt_step<=filt_step+1'b1;
                            // step 0 -> 1 issues the next write (state 0);
                            // step 780 -> 781 is the done marker (state 5).
                            state <= (filt_step == 12'd780) ? 5 : 0;
                        end
                    end else if(filt_step == 12'd781) begin
                        runtime_filt<=1'b0;
                        freq_busy<=1'b0;
                        runtime_done_latched<=1'b1;
                        state<=5;
                    end else begin
                        filt_step<=filt_step+1'b1;
                        state<=0;
                    end
                end else if(runtime_mode) begin
                    if(runtime_tx_switch) begin
                        if(runtime_step==0) begin
                            // UG-570 requires ENSM transition time before readback.
                            if(wait_cnt!=32'd6250) wait_cnt<=wait_cnt+1'b1;
                            else begin wait_cnt<=0; runtime_step<=5'd1; state<=0; end
                        end else if(runtime_step==2) begin
                            runtime_mode<=0;
                            runtime_tx_switch<=0;
                            last_tx_enable<=runtime_tx_target;
                            freq_busy<=0;
                            runtime_done_latched<=1'b1;
                            runtime_error_latched<=runtime_failed;
                        end else begin
                            runtime_failed<=1'b1;
                            runtime_step<=5'd2;
                        end
                    end else if(runtime_step==0 || runtime_step==27 ||
                                runtime_step==58 || runtime_step==65) begin
                        // Settle after ALERT, after each complete LO update
                        // (the 0x005 LO-divider write), and after FDD restore.
                        if(wait_cnt!=32'd6250) wait_cnt<=wait_cnt+1'b1;
                        else begin wait_cnt<=0; runtime_step<=runtime_step+1'b1; state<=0; end
                    end else if(runtime_step==67) begin
                        runtime_mode<=0;
                        last_tx_enable<=runtime_tx_target;
                        freq_busy<=0;
                        freq_done<=1;
                        freq_error<=runtime_failed;
                        runtime_done_latched<=1'b1;
                        runtime_error_latched<=runtime_failed;
                    end else begin
                        runtime_step<=runtime_step+1'b1;
                        state<=0;
                    end
                end else if(init_index==INIT_LAST) begin
                    // Absorb the VIO power-up level once. Only a later toggle
                    // is a real runtime request, so the LUT startup LO is not
                    // overwritten by tx_freq_index=0 immediately after reset.
                    if(!req_armed) begin
                        req_seen<=req_sync;
                        // Force one update after initialization. This also
                        // applies a VIO frequency selected before init_done.
//                        last_tx_index<=12'hfff;
//                        last_rx_index<=10'h3ff;
                          last_tx_index<=tx_index_sync;
                          last_rx_index<=rx_index_sync;
                          req_armed<=1'b1;
                    end else if(!tx_req_armed) begin
                        // The LUT ends in forced FDD TX (0x014=0x65).
                        last_tx_enable<=1'b1;
                        tx_req_armed<=1'b1;
                    end else if(tx_enable_sync!=last_tx_enable) begin
                        runtime_tx_target<=tx_enable_sync;
                        runtime_step<=0;
                        runtime_mode<=1;
                        runtime_tx_switch<=1;
                        runtime_failed<=0;
                        runtime_done_latched<=0;
                        runtime_error_latched<=0;
                        wait_cnt<=0;
                        freq_busy<=1;
                        state<=0;
                    end else if(req_sync!=req_seen ||
                                tx_index_sync!=last_tx_index ||
                                rx_index_sync!=last_rx_index) begin
                        req_seen<=req_sync;
                        last_tx_index<=tx_index_sync;
                        last_rx_index<=rx_index_sync;
                        runtime_tx_word<=tx_rom[tx_index];
                        runtime_rx_word<=rx_rom[rx_index];
                        runtime_step<=0;
                        runtime_mode<=1;
                        runtime_tx_switch<=0;
                        runtime_tx_target<=tx_enable_sync;
                        runtime_failed<=0;
                        runtime_done_latched<=0;
                        runtime_error_latched<=0;
                        debug_tx271<=0;
                        debug_tx287<=0;
                        lock_poll_count<=0;
                        wait_cnt<=0;
                        freq_busy<=1;
                        freq_error<=0;
                        state<=0;
                    end else if(!filt_first_done || (mode_sync != last_mode)) begin
                        // Apply the per-mode TX filter (FIR + BBF + secondary cal).
                        // First pass after init always runs to load the current mode's
                        // profile; later mode changes trigger a re-program.
                        filt_first_done<=1'b1;
                        last_mode<=mode_sync;
                        filt_target_mode<=mode_sync;
                        filt_step<=12'd0;
                        runtime_filt<=1'b1;
                        runtime_done_latched<=1'b0;
                        runtime_error_latched<=1'b0;
                        wait_cnt<=0;
                        lock_poll_count<=0;
                        freq_busy<=1'b1;
                        state<=0;
                    end
                end else if(init_index==13) begin
                    if(wait_cnt!=32000) wait_cnt<=wait_cnt+1'b1; else begin wait_cnt<=0; init_index<=init_index+1'b1; state<=0; end
                end else if(init_index==1629) begin
                    if(wait_cnt!=1600) wait_cnt<=wait_cnt+1'b1; else begin wait_cnt<=0; init_index<=init_index+1'b1; state<=0; end
                end else begin init_index<=init_index+1'b1; state<=0; end
                default: state<=5;
            endcase
        end
    end
    
    
    ad9361_spi_if u_spi_if(.rst(rst_n),.clk(clk),.addr(addr),.din(din),.din_en(din_en),.wr_rdn(wr_rdn),
        .dout(spi_dout),.dout_en(spi_dout_en),.spi_busy(spi_busy),.sclk(sclk),.sdi(sdi),.csb(csb),.sdo(sdo));
        
endmodule
