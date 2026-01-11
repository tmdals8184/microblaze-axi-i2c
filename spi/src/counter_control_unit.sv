`timescale 1ns / 1ps

module counter_control_unit (
    input  logic clk,
    input  logic reset,
    input  logic btn_runstop,
    input  logic btn_clear,
    output logic runstop,
    output logic clear
);

    typedef enum {
        IDLE,
        RUN,
        CLEAR
    } state_t;
    state_t state, state_next;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state <= IDLE;
        end else begin
            state <= state_next;
        end
    end

    always_comb begin
        state_next = state;
        runstop    = 1'b0;
        clear      = 1'b0;
        case (state)
            IDLE: begin
                if (btn_runstop) state_next = RUN;
                else if (btn_clear) state_next = CLEAR;
            end
            RUN: begin
                runstop = 1'b1;
                if (btn_runstop) state_next = IDLE;
            end
            CLEAR: begin
                clear      = 1'b1;
                state_next = IDLE;
            end
        endcase
    end

endmodule
