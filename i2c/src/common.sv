`timescale 1ns / 1ps

module tick_gen #(
    parameter FREQ  = 100_000 / 4,
    parameter F_CNT = 100_000_000 / FREQ
) (
    input  logic clk,
    input  logic reset,
    input  logic clear,
    output logic tick
);
    logic [$clog2(F_CNT)-1:0] r_cnt;
    always_ff @(posedge clk, posedge reset) begin
        if (reset | clear) begin
            r_cnt <= 0;
            tick  <= 1'b0;
        end else begin
            if (r_cnt == F_CNT - 1) begin
                r_cnt <= 0;
                tick  <= 1'b1;
            end else begin
                r_cnt <= r_cnt + 1;
                tick  <= 1'b0;
            end
        end
    end
endmodule