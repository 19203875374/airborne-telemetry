`timescale 1ns/1ps
module system_top (
    input wire mclk1, input wire resetb, output wire data_clk_n,
    output wire spi_clk, output wire spi_csn, input wire spi_miso, output wire spi_mosi,
    output wire en_agc, input wire enable, input wire txnrx,
    input wire rx_clk_in_p, input wire [5:0] rx_data_in_p, input wire rx_frame_in_p,
    output wire tx_clk_out_p, output wire [5:0] tx_data_out_p, output wire tx_frame_out_p,
    output wire [5:0] P1_D11_D6
);
    wire clk80,clk10,sys_clk20,clk122,sys_locked;
    CLK_PLL_sys u_sys(.clk_out1(clk80),.clk_out2(clk10),.clk_out3(sys_clk20),.clk_out4(clk122),
        .reset(!resetb),.locked(sys_locked),.clk_in1(mclk1));
    wire data_clk,iddr_clk,oddr_clk,sample_clk,rf_clk_locked;
    pll_ad9361 u_rfclk(.clk_out1(data_clk),.clk_out2(iddr_clk),.clk_out3(oddr_clk),
        .clk_out4(sample_clk),.reset(!resetb),.locked(rf_clk_locked),.clk_in1(rx_clk_in_p));
    wire sys_rst_n,sample_rst_n,data_rst_n;
    reset_sync u_rs(.clk(sys_clk20),.arst_n(resetb&&sys_locked),.srst_n(sys_rst_n));
    reset_sync u_rsm(.clk(sample_clk),.arst_n(resetb&&rf_clk_locked),.srst_n(sample_rst_n));
    reset_sync u_rd(.clk(data_clk),.arst_n(resetb&&rf_clk_locked),.srst_n(data_rst_n));
       
    // VIO: mode 0=PCM/1=NET; PCM 0=FM/1=SOQPSK; NET 0=BPSK/1=QPSK.
    wire mode_sel,pcm_mod_sel,net_mod_sel,tx_enable,rx_enable,freq_req;
    wire [11:0] tx_freq_index; wire [9:0] rx_freq_index;
    (* KEEP = "TRUE", DONT_TOUCH = "TRUE" *) reg [31:0] status;
    vio_trx_ctrl u_vio(.clk(sys_clk20),.probe_in0(status),.probe_out0(mode_sel),
        .probe_out1(pcm_mod_sel),.probe_out2(net_mod_sel),.probe_out3(tx_enable),
        .probe_out4(rx_enable),.probe_out5(tx_freq_index),.probe_out6(rx_freq_index),
        .probe_out7(freq_req));

   (* ASYNC_REG = "TRUE" *) reg [1:0] ctl_meta;
   (* ASYNC_REG = "TRUE" *) reg [1:0] ctl_sync;
   (* ASYNC_REG = "TRUE" *) reg txe_meta;
   (* ASYNC_REG = "TRUE", mark_debug = "true" *) reg txe_sync;
   
    always @(posedge sample_clk or negedge sample_rst_n)
        if(!sample_rst_n) begin ctl_meta<=0;ctl_sync<=0;txe_meta<=0;txe_sync<=0; end
        else begin ctl_meta<={mode_sel,mode_sel?net_mod_sel:pcm_mod_sel};ctl_sync<=ctl_meta;txe_meta<=tx_enable;txe_sync<=txe_meta;end
  
    (* mark_debug = "true" *) wire signed [11:0] bb_i;
    (* mark_debug = "true" *) wire signed [11:0] bb_q;
    (* mark_debug = "true" *) wire bb_valid;
    (* mark_debug = "true" *) wire pcm_bit_en;
    (* mark_debug = "true" *) wire net_sym_en;
    (* mark_debug = "true" *) wire [1:0] active_mode;
    (* mark_debug = "true" *) wire [1:0] psk_din_debug;
    (* mark_debug = "true" *) wire signed [11:0] psk_i_imp_debug;
    (* mark_debug = "true" *) wire signed [11:0] psk_q_imp_debug;
    (* mark_debug = "true" *) wire psk_sym_valid_debug;
    (* mark_debug = "true" *) wire [14:0] psk_prbs_debug;
    (* mark_debug = "true" *) wire [1:0] psk_din_used_debug;
    multi_mode_baseband_tx u_bb(.clk(sample_clk),.rst_n(sample_rst_n),.tx_enable(txe_sync),
        .mode_sel(ctl_sync[1]),.pcm_mod_sel(ctl_sync[0]),.net_mod_sel(ctl_sync[0]),
        .i_out(bb_i),.q_out(bb_q),.sample_valid(bb_valid),.pcm_bit_en(pcm_bit_en),
        .net_sym_en(net_sym_en),.mode_active(active_mode),
        .psk_din_debug(psk_din_debug),.psk_i_imp_debug(psk_i_imp_debug),
        .psk_q_imp_debug(psk_q_imp_debug),.psk_sym_valid_debug(psk_sym_valid_debug),
        .psk_prbs_debug(psk_prbs_debug),.psk_din_used_debug(psk_din_used_debug));

    (* mark_debug = "true" *) wire [31:0] fifo_dout;
    (* mark_debug = "true" *) wire fifo_empty;
    (* mark_debug = "true" *) wire fifo_rd_en;
    (* mark_debug = "true" *) wire [7:0] fifo_level;
    wire fifo_full;  
    (* mark_debug = "true" *) wire tx_underflow;
    
    

// Deterministic complex tone:
// Fs = 30.72 MHz, 32 samples/period, fBB = 30.72 MHz / 32 = 0.96 MHz.
// Every accepted FIFO sample advances the phase; no phase value is repeated.
reg [4:0] tone_index;
reg signed [11:0] tone_i_lut;
reg signed [11:0] tone_q_lut;
/////���ָ��������� I/Q��tone_i_test/tone_q_test��
wire signed [11:0] tone_i_test = txe_sync ? tone_i_lut : 12'sd0;
wire signed [11:0] tone_q_test = txe_sync ? tone_q_lut : 12'sd0;

// �㶨I��Q=0���ԣ�TX����ʱ��� I=1024��Q=0
//wire signed [11:0] tone_i_test = txe_sync ? 12'sd1024 : 12'sd0;
//wire signed [11:0] tone_q_test = 12'sd0;

//// ȫ��I/Q��ϣ�TX�Ա��ֿ���
//wire signed [11:0] tone_i_test = 12'sd0;
//wire signed [11:0] tone_q_test = 12'sd0;

//wire signed [11:0] tone_i_test = txe_sync ? 12'sd1040 : 12'sd0;
//wire signed [11:0] tone_q_test = txe_sync ? 12'sd1040 : 12'sd0;

always @(posedge sample_clk or negedge sample_rst_n) begin
    if (!sample_rst_n || !txe_sync)
        tone_index <= 5'd0;
    else if (bb_valid && !fifo_full)
        tone_index <= tone_index + 5'd1;
end

always @* begin
    tone_i_lut = 12'sd0;
    tone_q_lut = 12'sd0;

    case (tone_index)
        5'd0:  begin tone_i_lut =  12'sd1024; tone_q_lut =  12'sd0;    end
        5'd1:  begin tone_i_lut =  12'sd1004; tone_q_lut =  12'sd200;  end
        5'd2:  begin tone_i_lut =  12'sd946;  tone_q_lut =  12'sd392;  end
        5'd3:  begin tone_i_lut =  12'sd851;  tone_q_lut =  12'sd569;  end
        5'd4:  begin tone_i_lut =  12'sd724;  tone_q_lut =  12'sd724;  end
        5'd5:  begin tone_i_lut =  12'sd569;  tone_q_lut =  12'sd851;  end
        5'd6:  begin tone_i_lut =  12'sd392;  tone_q_lut =  12'sd946;  end
        5'd7:  begin tone_i_lut =  12'sd200;  tone_q_lut =  12'sd1004; end
        5'd8:  begin tone_i_lut =  12'sd0;    tone_q_lut =  12'sd1024; end
        5'd9:  begin tone_i_lut = -12'sd200;  tone_q_lut =  12'sd1004; end
        5'd10: begin tone_i_lut = -12'sd392;  tone_q_lut =  12'sd946;  end
        5'd11: begin tone_i_lut = -12'sd569;  tone_q_lut =  12'sd851;  end
        5'd12: begin tone_i_lut = -12'sd724;  tone_q_lut =  12'sd724;  end
        5'd13: begin tone_i_lut = -12'sd851;  tone_q_lut =  12'sd569;  end
        5'd14: begin tone_i_lut = -12'sd946;  tone_q_lut =  12'sd392;  end
        5'd15: begin tone_i_lut = -12'sd1004; tone_q_lut =  12'sd200;  end
        5'd16: begin tone_i_lut = -12'sd1024; tone_q_lut =  12'sd0;    end
        5'd17: begin tone_i_lut = -12'sd1004; tone_q_lut = -12'sd200;  end
        5'd18: begin tone_i_lut = -12'sd946;  tone_q_lut = -12'sd392;  end
        5'd19: begin tone_i_lut = -12'sd851;  tone_q_lut = -12'sd569;  end
        5'd20: begin tone_i_lut = -12'sd724;  tone_q_lut = -12'sd724;  end
        5'd21: begin tone_i_lut = -12'sd569;  tone_q_lut = -12'sd851;  end
        5'd22: begin tone_i_lut = -12'sd392;  tone_q_lut = -12'sd946;  end
        5'd23: begin tone_i_lut = -12'sd200;  tone_q_lut = -12'sd1004; end
        5'd24: begin tone_i_lut =  12'sd0;    tone_q_lut = -12'sd1024; end
        5'd25: begin tone_i_lut =  12'sd200;  tone_q_lut = -12'sd1004; end
        5'd26: begin tone_i_lut =  12'sd392;  tone_q_lut = -12'sd946;  end
        5'd27: begin tone_i_lut =  12'sd569;  tone_q_lut = -12'sd851;  end
        5'd28: begin tone_i_lut =  12'sd724;  tone_q_lut = -12'sd724;  end
        5'd29: begin tone_i_lut =  12'sd851;  tone_q_lut = -12'sd569;  end
        5'd30: begin tone_i_lut =  12'sd946;  tone_q_lut = -12'sd392;  end
        default: begin tone_i_lut = 12'sd1004; tone_q_lut = -12'sd200; end
    endcase
end
    
    // Pure complex-tone diagnostic word; tx_enable selects tone or zero-I/Q.
       wire [31:0] tx_test_word = {tone_i_test, 4'b0, tone_q_test, 4'b0};

   // .din({bb_i,4'b0,bb_q,4'b0}) 
    fifo_128x64 u_fifo(.rst(!(resetb&&rf_clk_locked)),.wr_clk(sample_clk),.rd_clk(data_clk),
    .din({bb_i,4'b0,bb_q,4'b0}),
  //.din(tx_test_word),
    .wr_en(bb_valid&&!fifo_full),.rd_en(fifo_rd_en),
    .dout(fifo_dout),.full(fifo_full),.empty(fifo_empty),.rd_data_count(fifo_level));
        
     ad9361_cmos_tx_if u_txif(
         .data_clk(data_clk),
         .oddr_clk(oddr_clk),
         // Keep the 0F interface timing unchanged so 10 tests only the tone source.
         .fb_clk(oddr_clk),
         .rst_n(data_rst_n),
         .fifo_dout(fifo_dout),
         .fifo_empty(fifo_empty),
         .fifo_level(fifo_level),
         .fifo_rd_en(fifo_rd_en),
         .tx_clk_out_p(tx_clk_out_p),
         .tx_frame_out_p(tx_frame_out_p),
         .tx_data_out_p(tx_data_out_p),
         .underflow(tx_underflow)
     );


    (* mark_debug = "true" *) wire signed [11:0] rx_i;
    (* mark_debug = "true" *) wire signed [11:0] rx_q;
    (* mark_debug = "true" *) wire rx_sample_valid;
    ad9361_cmos_rx_if u_rxif(.data_clk(data_clk),.rst_n(data_rst_n),.rx_data(rx_data_in_p),
        .rx_frame(rx_frame_in_p),.rx_i(rx_i),.rx_q(rx_q),.sample_valid(rx_sample_valid));
        
   (* ASYNC_REG = "TRUE" *) reg rxen_meta;
   (* ASYNC_REG = "TRUE" *) reg rxen_sync;
   (* ASYNC_REG = "TRUE" *) reg net_meta;
   (* ASYNC_REG = "TRUE" *) reg net_sync;
   (* ASYNC_REG = "TRUE" *) reg qpsk_meta;  
   (* ASYNC_REG = "TRUE" *) reg qpsk_sync;
    always @(posedge data_clk or negedge data_rst_n)
        if(!data_rst_n) begin rxen_meta<=0;rxen_sync<=0;net_meta<=0;net_sync<=0;qpsk_meta<=0;qpsk_sync<=0;end
        else begin rxen_meta<=rx_enable;rxen_sync<=rxen_meta;net_meta<=mode_sel;net_sync<=net_meta;
            qpsk_meta<=net_mod_sel;qpsk_sync<=qpsk_meta;end
                   
    (* mark_debug = "true" *) wire [1:0] rx_bits;
    (* mark_debug = "true" *) wire rx_bits_valid;
    
        psk_demod #(
            .OSR(4)
        ) u_demod (
            .clk(data_clk),
            .rst_n(data_rst_n),
            .enable(rxen_sync && net_sync),
            .qpsk_mode(qpsk_sync),
            .i_in(rx_i),
            .q_in(rx_q),
            .sample_valid(rx_sample_valid),
            .data_out(rx_bits),
            .data_valid(rx_bits_valid)
        );
        
    reg [4:0] spi_div; always @(posedge sys_clk20 or negedge sys_rst_n) if(!sys_rst_n)spi_div<=0;else spi_div<=spi_div+1'b1;
    wire spi_rst_n; reset_sync u_rsp(.clk(spi_div[4]),.arst_n(sys_rst_n),.srst_n(spi_rst_n));
    wire [7:0] rfpll_status,spi_debug_data; wire [11:0] spi_init_index;
    wire [7:0] debug_tx271,debug_tx287,debug_reg002,debug_reg014;
    wire runtime_done_latched,runtime_error_latched;
    wire init_done,freq_busy,freq_done,freq_error;
    ad9361_spi_ctrl u_spi(.rst_n(spi_rst_n),.clk(spi_div[4]),.tx_freq_index(tx_freq_index),
        .rx_freq_index(rx_freq_index),.freq_req_toggle(freq_req),.tx_enable_req(tx_enable),
        .mode_in(active_mode),
        .rfpll_status(rfpll_status),.debug_init_index(spi_init_index),.debug_spi_dout(spi_debug_data),
        .debug_tx271(debug_tx271),.debug_tx287(debug_tx287),
        .debug_reg002(debug_reg002),.debug_reg014(debug_reg014),
        .runtime_done_latched(runtime_done_latched),
        .runtime_error_latched(runtime_error_latched),
        .init_done(init_done),.freq_busy(freq_busy),.freq_done(freq_done),.freq_error(freq_error),
        .sclk(spi_clk),.sdi(spi_mosi),.csb(spi_csn),.sdo(spi_miso));

    // Register the complete status word in the VIO clock domain so Vivado
    // preserves and displays it as one 32-bit probe instead of scalar fields.
    always @(posedge sys_clk20 or negedge sys_rst_n) begin
        if(!sys_rst_n)
            status <= 32'h0000_0015;
        else
            status <= {debug_tx287,debug_tx271,freq_error,
                runtime_error_latched,runtime_done_latched,freq_busy,init_done,
                rf_clk_locked,sys_locked,txe_sync,active_mode,fifo_empty,fifo_full,
                4'b0000};
                
    end
    assign en_agc=1'b1; assign data_clk_n=1'b0;
    assign P1_D11_D6={rx_bits_valid,rx_bits,active_mode,init_done};
    wire unused=&{1'b0,enable,txnrx,iddr_clk,clk80,clk10,clk122};
    
endmodule
