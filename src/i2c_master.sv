`timescale 1ns / 1ps

`include "define.sv"

module i2c_master (
    // global signal
    input  logic       clk,
    input  logic       reset,
    // internal signal
    input  logic       i2c_en,
    input  logic       i2c_stop,
    input  logic       i2c_start,
    input  logic       i2c_mack,
    input  logic       i2c_trig,
    input  logic [7:0] i2c_tdr,
    output logic [7:0] i2c_rdr,
    output logic [5:0] i2c_sr,
    // external signal
    inout  logic       SDA,
    output logic       SCL
);
    /****** tick & phase gen *******/
    logic [1:0] phase_cnt;
    logic phase_tick, phase_clear;
    logic bit_end;
    wire  bit_middle = phase_tick && (phase_cnt == 2'd1);

    tick_gen U_TickGen (.*);
    phase_gen U_PhaseGen (.*);

    /*************** ***************/

    i2c_sr_t i2c_sr_reg, i2c_sr_next;
    mst_state_t state, state_next;

    logic sda_en, sda_out;
    logic [7:0] i2c_tdr_reg, i2c_tdr_next;
    logic [7:0] i2c_rdr_reg, i2c_rdr_next;
    logic [2:0] bit_cnt_reg, bit_cnt_next;

    assign SDA     = sda_en ? sda_out : 1'bz;
    assign i2c_rdr = i2c_rdr_reg;
    assign i2c_sr  = i2c_sr_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state       <= IDLE;
            i2c_sr_reg  <= '0;
            i2c_tdr_reg <= 0;
            i2c_rdr_reg <= 0;
            bit_cnt_reg <= 0;
        end else begin
            state       <= state_next;
            i2c_sr_reg  <= i2c_sr_next;
            i2c_tdr_reg <= i2c_tdr_next;
            i2c_rdr_reg <= i2c_rdr_next;
            bit_cnt_reg <= bit_cnt_next;
        end
    end

    always_comb begin
        sda_en  = 1'b1;
        sda_out = 1'b1;
        SCL     = 1'b1;
        case (state)
            READ:   sda_en = 1'b0;
            ACK_RW: sda_en = i2c_sr_reg.is_read;
        endcase
        case (state)
            IDLE, HOLD: sda_out = 1'b1;
            START:      sda_out = 1'b0;
            STOP:       sda_out = phase_cnt[1];
            WRITE:      sda_out = i2c_tdr_reg[7];
            ACK_RW:     sda_out = i2c_sr_reg.is_nack;
        endcase
        case (state)
            IDLE, STOP:          SCL = 1'b1;
            HOLD:                SCL = 1'b0;
            START:               SCL = ~phase_cnt[1];
            WRITE, READ, ACK_RW: SCL = ^phase_cnt;
        endcase
    end

    always_comb begin
        state_next   = state;
        i2c_sr_next  = i2c_sr_reg;
        i2c_tdr_next = i2c_tdr_reg;
        i2c_rdr_next = i2c_rdr_reg;
        bit_cnt_next = bit_cnt_reg;
        phase_clear  = 1'b0;
        case (state)
            IDLE: begin
                phase_clear = 1'b1;
                i2c_sr_next = '0;
                if (i2c_en) begin
                    state_next          = START;
                    i2c_sr_next.mst_rdy = 1'b1;
                end
            end
            HOLD: begin
                phase_clear = 1'b1;
                if (i2c_trig) begin
                    i2c_sr_next.rx_done = 1'b0;
                    i2c_sr_next.tx_done = 1'b0;
                    case ({
                        i2c_start, i2c_stop
                    })
                        2'b00: begin
                            i2c_tdr_next        = i2c_tdr;
                            i2c_sr_next.is_read = 1'b0;
                            state_next          = WRITE;
                        end
                        2'b01: begin
                            state_next = STOP;
                        end
                        2'b10: begin
                            state_next = START;
                        end
                        2'b11: begin
                            i2c_sr_next.is_read = 1'b1;
                            i2c_sr_next.is_nack = i2c_mack;
                            state_next          = READ;
                        end
                    endcase
                end
            end
            START: begin
                if (bit_end) begin
                    i2c_sr_next.st_done = 1'b1;
                    state_next          = HOLD;
                end
            end
            WRITE: begin
                if (bit_end) begin
                    if (bit_cnt_reg == 7) begin
                        bit_cnt_next = 0;
                        if (i2c_sr_reg.st_done) begin
                            i2c_sr_next.st_done = 1'b0;
                            i2c_sr_next.is_addr = 1'b1;
                        end else i2c_sr_next.is_addr = 1'b0;
                        state_next = ACK_RW;
                    end else begin
                        bit_cnt_next = bit_cnt_reg + 1;
                        i2c_tdr_next = {i2c_tdr_reg[6:0], 1'b0};
                    end
                end
            end
            READ: begin
                if (bit_middle) i2c_rdr_next = {i2c_rdr_reg[6:0], SDA};
                if (bit_end) begin
                    if (bit_cnt_reg == 7) begin
                        bit_cnt_next = 0;
                        state_next   = ACK_RW;
                    end else begin
                        bit_cnt_next = bit_cnt_reg + 1;
                    end
                end
            end
            ACK_RW: begin
                if (bit_middle && !i2c_sr_reg.is_read) begin
                    i2c_sr_next.is_nack = SDA;
                end
                if (bit_end) begin
                    i2c_sr_next.tx_done = ~i2c_sr_reg.is_read;
                    i2c_sr_next.rx_done = i2c_sr_reg.is_read;
                    state_next          = i2c_sr_reg.is_nack ? STOP : HOLD;
                end
            end
            STOP: begin
                if (bit_end) begin
                    phase_clear = 1'b1;
                    state_next  = IDLE;
                end
            end
        endcase
    end
endmodule

module phase_gen (
    input  logic       clk,
    input  logic       reset,
    input  logic       phase_tick,
    input  logic       phase_clear,
    output logic [1:0] phase_cnt,
    output logic       bit_end
);
    logic [1:0] phase_cnt_reg, phase_cnt_next;
    logic bit_end_reg;

    assign phase_cnt = phase_cnt_reg;
    assign bit_end   = bit_end_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            phase_cnt_reg <= 0;
            bit_end_reg   <= 1'b0;
        end else begin
            phase_cnt_reg <= phase_cnt_next;
            bit_end_reg   <= (phase_cnt_reg == 3) & phase_tick;
        end
    end

    always_comb begin
        phase_cnt_next = phase_cnt_reg;
        if (phase_clear) begin
            phase_cnt_next = 0;
        end else if (phase_tick) begin
            if (phase_cnt_reg == 3) phase_cnt_next = 0;
            else phase_cnt_next = phase_cnt_reg + 1;
        end
    end
endmodule

module tick_gen #(
    parameter FREQ = 100_000
) (
    input  logic clk,
    input  logic reset,
    input  logic phase_tick_clear,
    output logic phase_tick
);
    localparam PHASE_WIDTH = (100_000_000 / FREQ) / 4;

    logic [$clog2(PHASE_WIDTH)-1:0] clk_cnt;

    always_ff @(posedge clk, posedge reset) begin
        if (reset | phase_tick_clear) begin
            clk_cnt    <= 0;
            phase_tick <= 1'b0;
        end else begin
            if (clk_cnt == PHASE_WIDTH - 1) begin
                clk_cnt <= 0;
                phase_tick <= 1'b1;
            end else begin
                clk_cnt    <= clk_cnt + 1;
                phase_tick <= 1'b0;
            end
        end
    end
endmodule
