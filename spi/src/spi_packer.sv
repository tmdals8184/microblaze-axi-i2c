`timescale 1ns / 1ps

module spi_packer (
    input  logic        clk,
    input  logic        reset,
    input  logic [13:0] cnt_data,
    output logic [ 7:0] tx_data,
    output logic        start,
    input  logic        tx_ready,
    input  logic        done,
    output logic        cs
);
    typedef enum {
        IDLE,
        SEND_H,
        WAIT,
        SEND_L
    } state_t;

    state_t state, state_next;
    logic [13:0] cnt_buf_reg, cnt_buf_next;
    logic start_reg, start_next;
    logic byte_sel;

    wire [13:0] cnt_buf_data = cnt_buf_reg;

    data_slicer U_Slicer (.*);

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state       <= IDLE;
            cnt_buf_reg <= 0;
        end else begin
            state       <= state_next;
            cnt_buf_reg <= cnt_buf_next;
        end
    end

    always_comb begin
        state_next   = state;
        cnt_buf_next = cnt_buf_reg;
        start        = 1'b0;
        cs           = 1'b1;
        byte_sel     = 1'b1;
        case (state)
            IDLE: begin
                if (tx_ready) begin
                    cnt_buf_next = cnt_data;
                    byte_sel     = 1'b1;
                    start        = 1'b1;
                    state_next   = SEND_H;
                end
            end
            SEND_H: begin
                cs       = 1'b0;
                byte_sel = 1'b1;
                if (done) begin
                    // start      = 1'b1;
                    state_next = WAIT;
                end
            end
            WAIT: begin
                cs = 1'b0;
                if (tx_ready) begin
                    byte_sel   = 1'b0;
                    start      = 1'b1;
                    state_next = SEND_L;
                end
            end
            SEND_L: begin
                cs       = 1'b0;
                byte_sel = 1'b0;
                if (done) begin
                    state_next = IDLE;
                end
            end
        endcase
    end

endmodule

module data_slicer (
    input  logic        byte_sel,
    input  logic [13:0] cnt_buf_data,
    output logic [ 7:0] tx_data
);
    assign tx_data = (byte_sel) 
                    ? {1'b1, cnt_buf_data[13:7]} 
                    : {1'b0, cnt_buf_data[6:0]};
endmodule
