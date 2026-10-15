`timescale 1ns/1ps

// Asynchronous assertion, synchronous deassertion reset synchronizer.
module reset_sync (
    input  wire clk,
    input  wire arst_n,
    output wire srst_n
);
    (* ASYNC_REG = "TRUE" *) reg [2:0] sync_ff;

    always @(posedge clk or negedge arst_n) begin
        if (!arst_n)
            sync_ff <= 3'b000;
        else
            sync_ff <= {sync_ff[1:0], 1'b1};
    end

    assign srst_n = sync_ff[2];
endmodule
