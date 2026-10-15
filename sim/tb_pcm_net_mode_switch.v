`timescale 1ns/1ps

// Self-checking testbench for the two-level transmit-mode architecture:
//   mode_sel=0: pcm_mod_sel=0 PCM-FM, pcm_mod_sel=1 SOQPSK-TG
//   mode_sel=1: net_mod_sel=0 BPSK,    net_mod_sel=1 QPSK
// This unit-level simulation does not require the AD9361/VIO/FIFO IP models.
module tb_pcm_net_mode_switch;
    localparam integer SETTLE_SAMPLES = 288; // > 128-sample switch mute
    // 30.72 MHz * 1 ms = 30720 samples. The first visit to each of the
    // four modulation modes is therefore held for 1 ms of valid waveform.
    localparam integer MODE_HOLD_SAMPLES   = 30720;

    // Reverse-direction switching is checked with a shorter interval so
    // that PCM-FM and BPSK are not unnecessarily recorded for another 1 ms.
    localparam integer RETURN_CHECK_SAMPLES = 1024;

    reg clk;
    reg rst_n;
    reg tx_enable;
    reg mode_sel;
    reg pcm_mod_sel;
    reg net_mod_sel;

    wire signed [11:0] i_out;
    wire signed [11:0] q_out;
    wire sample_valid;
    wire pcm_bit_en;
    wire net_sym_en;
    wire [1:0] mode_active;
    wire [1:0] psk_din_debug;
    wire signed [11:0] psk_i_imp_debug;
    wire signed [11:0] psk_q_imp_debug;
    wire psk_sym_valid_debug;
    wire [14:0] psk_prbs_debug;
    wire [1:0] psk_din_used_debug;

    integer fd;
    integer sample_no;
    integer errors;
    integer mapping_checks;
    reg [1:0] din_at_symbol;
    integer expected_i_imp;
    integer expected_q_imp;
    integer map_fd;

    multi_mode_baseband_tx dut (
        .clk(clk),
        .rst_n(rst_n),
        .tx_enable(tx_enable),
        .mode_sel(mode_sel),
        .pcm_mod_sel(pcm_mod_sel),
        .net_mod_sel(net_mod_sel),
        .i_out(i_out),
        .q_out(q_out),
        .sample_valid(sample_valid),
        .pcm_bit_en(pcm_bit_en),
        .net_sym_en(net_sym_en),
        .mode_active(mode_active),
        .psk_din_debug(psk_din_debug),
        .psk_i_imp_debug(psk_i_imp_debug),
        .psk_q_imp_debug(psk_q_imp_debug),
        .psk_sym_valid_debug(psk_sym_valid_debug),
        .psk_prbs_debug(psk_prbs_debug),
        .psk_din_used_debug(psk_din_used_debug)
    );

    // 30.72 MHz complex-sample clock: T = 32.552083 ns.
    initial clk = 1'b0;

    
    always #16.2760417 clk = ~clk;

    // Export one row per valid complex sample for MATLAB/post-processing.
    always @(posedge clk) begin
        if (rst_n && sample_valid) begin
            sample_no = sample_no + 1;
            $fwrite(fd, "%0d %0d %0d %0d %0d %0d %0d %0d %0d\n",
                    sample_no, mode_sel, pcm_mod_sel, net_mod_sel,
                    mode_active, $signed(i_out), $signed(q_out),
                    pcm_bit_en, net_sym_en);
        end
    end

    // One row per symbol event: input bits, pre-RRC mapped symbol and
    // post-RRC waveform sample. The pre-RRC values are the mapping evidence.
    always @(posedge clk) begin
        if (rst_n && psk_sym_valid_debug) begin
            #1;
            $fwrite(map_fd, "%0d %0d %0d %0d %0d %0d %0d\n",
                sample_no, mode_active, psk_din_used_debug,
                $signed(psk_i_imp_debug), $signed(psk_q_imp_debug),
                $signed(i_out), $signed(q_out));
        end
    end

    // Check the impulse mapping at every PSK symbol. Capture din before the
    // PRBS nonblocking update, then inspect i_imp/q_imp after the same edge.
    always @(posedge clk) begin
        if (rst_n && net_sym_en &&
            ((mode_active == 2'b10) || (mode_active == 2'b11))) begin
            #1;
            din_at_symbol = psk_din_used_debug;
            expected_i_imp = din_at_symbol[0] ? 950 : -950;
            expected_q_imp = din_at_symbol[1] ? 950 : -950;
            mapping_checks = mapping_checks + 1;
            if ($signed(psk_i_imp_debug) !== expected_i_imp) begin
                $display("ERROR: I mapping, active=%b din=%b got=%0d expected=%0d",
                         mode_active, din_at_symbol,
                         $signed(psk_i_imp_debug), expected_i_imp);
                errors = errors + 1;
            end
            if (mode_active == 2'b10) begin
                if ($signed(psk_q_imp_debug) !== 0) begin
                    $display("ERROR: BPSK q_imp must be zero, got=%0d",
                             $signed(psk_q_imp_debug));
                    errors = errors + 1;
                end
            end else if ($signed(psk_q_imp_debug) !== expected_q_imp) begin
                $display("ERROR: Q mapping, din=%b got=%0d expected=%0d",
                         din_at_symbol, $signed(psk_q_imp_debug), expected_q_imp);
                errors = errors + 1;
            end
        end
    end

    task wait_samples;
        input integer count;
        integer n;
        begin
            for (n = 0; n < count; n = n + 1)
                @(posedge clk);
            #1;
        end
    endtask

    task expect_active_mode;
        input [1:0] expected_mode;
        input [8*24-1:0] label_text;
        begin
            if (mode_active !== expected_mode) begin
                $display("ERROR: %0s active_mode=%b, expected=%b",
                         label_text, mode_active, expected_mode);
                errors = errors + 1;
            end else begin
                $display("PASS : %0s active_mode=%b", label_text, mode_active);
            end
        end
    endtask

    task check_selected_waveform;
        input [1:0] expected_mode;
        input [8*24-1:0] label_text;
        input integer check_count;
        integer n;
        integer i_nonzero;
        integer q_nonzero;
        integer i_positive;
        integer i_negative;
        integer q_positive;
        integer q_negative;
        begin
            i_nonzero  = 0;
            q_nonzero  = 0;
            i_positive = 0;
            i_negative = 0;
            q_positive = 0;
            q_negative = 0;

            for (n = 0; n < check_count; n = n + 1) begin
                @(posedge clk);
                #1;
                if (mode_active !== expected_mode) begin
                    $display("ERROR: %0s changed active_mode during check", label_text);
                    errors = errors + 1;
                end
                if ($signed(i_out) != 0) i_nonzero = i_nonzero + 1;
                if ($signed(q_out) != 0) q_nonzero = q_nonzero + 1;
                if ($signed(i_out) > 0)  i_positive = i_positive + 1;
                if ($signed(i_out) < 0)  i_negative = i_negative + 1;
                if ($signed(q_out) > 0)  q_positive = q_positive + 1;
                if ($signed(q_out) < 0)  q_negative = q_negative + 1;

                // Prove that the selected output is connected to the intended
                // modulation branch, not merely that some waveform exists.
                case (expected_mode)
                    2'b00: if ((i_out !== dut.fm_i) || (q_out !== dut.fm_q)) begin
                        $display("ERROR: PCM-FM selector mismatch at sample %0d", sample_no);
                        errors = errors + 1;
                    end
                    2'b01: if ((i_out !== dut.soqpsk_i) || (q_out !== dut.soqpsk_q)) begin
                        $display("ERROR: SOQPSK selector mismatch at sample %0d", sample_no);
                        errors = errors + 1;
                    end
                    2'b10, 2'b11:
                        if ((i_out !== dut.psk_i) || (q_out !== dut.psk_q)) begin
                            $display("ERROR: PSK selector mismatch at sample %0d", sample_no);
                            errors = errors + 1;
                        end
                endcase
            end

            case (expected_mode)
                2'b00, 2'b01: begin
                    if ((i_nonzero == 0) || (q_nonzero == 0)) begin
                        $display("ERROR: %0s must have valid I and Q", label_text);
                        errors = errors + 1;
                    end
                end
                2'b10: begin
                    if (i_nonzero == 0) begin
                        $display("ERROR: BPSK I output is inactive");
                        errors = errors + 1;
                    end
                    if (q_nonzero != 0) begin
                        $display("ERROR: BPSK Q output is not zero, count=%0d", q_nonzero);
                        errors = errors + 1;
                    end
                end
                2'b11: begin
                    if ((i_nonzero == 0) || (q_nonzero == 0) ||
                        (i_positive == 0) || (i_negative == 0) ||
                        (q_positive == 0) || (q_negative == 0)) begin
                        $display("ERROR: QPSK I/Q signs or activity incomplete");
                        errors = errors + 1;
                    end
                end
            endcase

            $display("INFO : %0s I_nz=%0d Q_nz=%0d I(+/-)=%0d/%0d Q(+/-)=%0d/%0d",
                     label_text, i_nonzero, q_nonzero,
                     i_positive, i_negative, q_positive, q_negative);
        end
    endtask

    task select_pcm;
        input requested_pcm_mod;
        input [1:0] expected_mode;
        input [8*24-1:0] label_text;
        input integer check_count;
        begin
            mode_sel   = 1'b0;
            pcm_mod_sel = requested_pcm_mod;
            wait_samples(SETTLE_SAMPLES);
            expect_active_mode(expected_mode, label_text);
            check_selected_waveform(expected_mode, label_text, check_count);
        end
    endtask

    task select_network;
        input requested_net_mod;
        input [1:0] expected_mode;
        input [8*24-1:0] label_text;
        input integer check_count;
        begin
            mode_sel  = 1'b1;
            net_mod_sel = requested_net_mod;
            wait_samples(SETTLE_SAMPLES);
            expect_active_mode(expected_mode, label_text);
            check_selected_waveform(expected_mode, label_text, check_count);
        end
    endtask

    initial begin
        rst_n          = 1'b0;
        tx_enable      = 1'b0;
        mode_sel       = 1'b0;
        pcm_mod_sel    = 1'b0;
        net_mod_sel    = 1'b0;
        sample_no      = 0;
        errors         = 0;
        mapping_checks = 0;
        
        din_at_symbol  = 2'b00;
        expected_i_imp = 0;
        expected_q_imp = 0;
        
        fd = $fopen("E:/TX/matlab/baseband_signal/pcm_net_mode_switch_iq.txt", "w");
        if (fd == 0) begin
            $display("FATAL: cannot create E:/TX/matlab/baseband_signal/pcm_net_mode_switch_iq.txt");
            $finish;
        end
        $fwrite(fd, "sample mode_sel pcm_mod_sel net_mod_sel active_mode i q pcm_bit_en net_sym_en\n");
        map_fd = $fopen("E:/TX/matlab/baseband_signal/psk_symbol_mapping.txt", "w");
        if (map_fd == 0) begin
            $display("FATAL: cannot create E:/TX/matlab/baseband_signal/psk_symbol_mapping.txt");
            $finish;
        end
        $fwrite(map_fd, "sample active_mode din_used[1:0] i_imp q_imp i_out q_out\n");

        wait_samples(12);
        rst_n     = 1'b1;
        tx_enable = 1'b1;

        // PCM main mode and its two sub-modulations. Each primary mode is
        // recorded for 30720 valid samples, corresponding to 1 ms.
        select_pcm(1'b0, 2'b00, "PCM / PCM-FM", MODE_HOLD_SAMPLES);

        // net_mod_sel is irrelevant while PCM mode is active.
        net_mod_sel = 1'b1;
        wait_samples(32);
        expect_active_mode(2'b00, "PCM ignores net_mod_sel");

        select_pcm(1'b1, 2'b01, "PCM / SOQPSK-TG", MODE_HOLD_SAMPLES);
        net_mod_sel = 1'b0;
        wait_samples(32);
        expect_active_mode(2'b01, "PCM ignores net_mod_sel");

        // Network main mode and its two sub-modulations.
        select_network(1'b0, 2'b10, "NET / BPSK", MODE_HOLD_SAMPLES);

        // pcm_mod_sel is irrelevant while network mode is active.
        pcm_mod_sel = 1'b0;
        wait_samples(32);
        expect_active_mode(2'b10, "NET ignores pcm_mod_sel");

        select_network(1'b1, 2'b11, "NET / QPSK", MODE_HOLD_SAMPLES);
        pcm_mod_sel = 1'b1;
        wait_samples(32);
        expect_active_mode(2'b11, "NET ignores pcm_mod_sel");

        // Exercise the reverse directions as well: QPSK -> BPSK and NET -> PCM.
        select_network(1'b0, 2'b10, "NET / BPSK return", RETURN_CHECK_SAMPLES);
        select_pcm(1'b0, 2'b00, "PCM / PCM-FM return", RETURN_CHECK_SAMPLES);

        // TX enable must mute both I and Q without changing the selected mode.
        tx_enable = 1'b0;
        wait_samples(4);
        if (($signed(i_out) != 0) || ($signed(q_out) != 0)) begin
            $display("ERROR: tx_enable=0 did not mute I/Q");
            errors = errors + 1;
        end else begin
            $display("PASS : tx_enable=0 mutes I/Q");
        end

        $fclose(fd);
        $fclose(map_fd);
        if (mapping_checks == 0) begin
            $display("ERROR: no PSK mapping checks were executed");
            errors = errors + 1;
        end

        $display("--------------------------------------------------");
        $display("Primary hold samples per mode = %0d (1 ms at 30.72 MHz)",
                 MODE_HOLD_SAMPLES);
        $display("PSK mapping checks = %0d", mapping_checks);
        if (errors == 0)
            $display("TEST PASS: PCM/NET switching and all sub-modulations are correct");
        else
            $display("TEST FAIL: total errors = %0d", errors);
        $display("Export file: E:/TX/matlab/baseband_signal/pcm_net_mode_switch_iq.txt");
        $display("Mapping table: E:/TX/matlab/baseband_signal/psk_symbol_mapping.txt");
        $display("--------------------------------------------------");
        $finish;
    end
endmodule
