`timescale 1ns / 1ps

module spi_unpacker (
    input  logic        clk,
    input  logic        reset,
    input  logic [ 7:0] si_data,
    input  logic        si_done,
    output logic        valid,
    output logic [13:0] cnt_data
);
    typedef enum {
        IDLE,
        RCV_H,
        RCV_L
    } state_t;

    state_t state, state_next;
    logic [13:0] cnt_buf_reg, cnt_buf_next;
    logic [6:0] data_h_reg, data_h_next;
    logic [6:0] data_l_reg, data_l_next;
    wire flag = si_data[7];

    assign cnt_data = cnt_buf_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state       <= IDLE;
            cnt_buf_reg <= 0;
            data_h_reg  <= 0;
            data_l_reg  <= 0;
        end else begin
            state       <= state_next;
            cnt_buf_reg <= cnt_buf_next;
            data_h_reg  <= data_h_next;
            data_l_reg  <= data_l_next;
        end
    end

    always_comb begin
        state_next   = state;
        cnt_buf_next = cnt_buf_reg;
        data_h_next  = data_h_reg;
        data_l_next  = data_l_reg;
        case (state)
            IDLE: begin
                if (si_done) begin
                    if (flag) begin
                        data_h_next = si_data[6:0];
                        state_next  = RCV_H;
                    end else begin
                        state_next = IDLE;
                    end
                end
            end
            RCV_H: begin
                if (si_done) begin
                    if (~flag) begin
                        data_l_next = si_data[6:0];
                        state_next  = RCV_L;
                    end else begin
                        state_next = IDLE;
                    end
                end
            end
            RCV_L: begin
                cnt_buf_next = {data_h_reg, data_l_reg};
                state_next   = IDLE;
            end
        endcase
    end

endmodule

