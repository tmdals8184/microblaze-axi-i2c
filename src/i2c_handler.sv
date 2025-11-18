`timescale 1ns / 1ps

module i2c_handler (
    // global signal
    input  logic       clk,
    input  logic       reset,
    // internal signal
    input  logic [7:0] recv_data,
    output logic [7:0] send_data,
    input  logic       recv_done,
    // input  logic       is_send,
    // external i/o
    output logic [7:0] led,
    input  logic [7:0] sw
);

    assign send_data = sw;
    logic [7:0] led_reg;
    assign led = led_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            led_reg <= 0;
        end else begin
            if (recv_done) begin
                led_reg <= recv_data;
            end
        end
    end
endmodule
