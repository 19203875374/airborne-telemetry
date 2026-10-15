`timescale 1ns/1ps
module tb_psk_demod;
    reg clk=0,rst_n=0,enable=0,qpsk=0,valid=0;
    reg signed [11:0] i_in=0,q_in=0;
    wire [1:0] data_out; wire data_valid;
    integer errors=0,k;
    psk_demod #(.OSR(8)) dut(.clk(clk),.rst_n(rst_n),.enable(enable),.qpsk_mode(qpsk),
        .i_in(i_in),.q_in(q_in),.sample_valid(valid),.data_out(data_out),.data_valid(data_valid));
    always #5 clk=~clk;
    task symbol; input [1:0] bits; begin
        i_in=bits[0]?12'sd700:-12'sd700; q_in=bits[1]?12'sd500:-12'sd500;
        for(k=0;k<8;k=k+1) begin valid=1; @(posedge clk); #1; end valid=0;
        if(!data_valid || data_out!==bits) begin $display("ERROR got=%b expected=%b",data_out,bits);errors=errors+1;end
    end endtask
    initial begin repeat(3)@(posedge clk);rst_n=1;enable=1;qpsk=1;
        symbol(2'b00);symbol(2'b01);symbol(2'b10);symbol(2'b11);
        if(errors==0)$display("TEST PASS: BPSK/QPSK hard demod");else $display("TEST FAIL %0d",errors);$finish;
    end
endmodule
