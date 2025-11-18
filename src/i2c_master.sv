`timescale 1ns / 1ps

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
    output logic       i2c_ready,
    // external signal
    inout  logic       SDA,
    output logic       SCL
);
    typedef struct packed {
        logic tx_done;
        logic rx_done;
        logic st_done;
        logic is_read;
        logic is_addr;
        logic is_nack;
    } i2c_sr_t;
    i2c_sr_t i2c_sr_reg, i2c_sr_next;
    typedef enum {
        IDLE,
        HOLD,
        START,
        STOP,
        WRITE,
        READ,
        ACK_RW
    } state_t;
    state_t state, state_next;
    logic sda_en, sda_out;
    logic [7:0] i2c_tdr_reg, i2c_tdr_next;
    logic [7:0] i2c_rdr_reg, i2c_rdr_next;
    logic [2:0] bit_cnt_reg, bit_cnt_next;
    logic [1:0] phase_cnt_reg, phase_cnt_next;

    logic scl_tick_clear, scl_tick;
    tick_gen U_TICK_GEN (.*);

    assign SDA     = sda_en ? sda_out : 1'bz;
    assign i2c_rdr = i2c_rdr_reg;
    assign i2c_sr  = i2c_sr_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state         <= IDLE;
            i2c_sr_reg    <= '0;
            i2c_tdr_reg   <= 0;
            i2c_rdr_reg   <= 0;
            bit_cnt_reg   <= 0;
            phase_cnt_reg <= 0;
        end else begin
            state         <= state_next;
            i2c_sr_reg    <= i2c_sr_next;
            i2c_tdr_reg   <= i2c_tdr_next;
            i2c_rdr_reg   <= i2c_rdr_next;
            bit_cnt_reg   <= bit_cnt_next;
            phase_cnt_reg <= phase_cnt_next;
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
            STOP:       sda_out = phase_cnt_reg[1];
            WRITE:      sda_out = i2c_tdr_reg[7];
            ACK_RW:     sda_out = i2c_sr_reg.is_nack;
        endcase
        case (state)
            IDLE, STOP:          SCL = 1'b1;
            HOLD:                SCL = 1'b0;
            START:               SCL = ~phase_cnt_reg[1];
            WRITE, READ, ACK_RW: SCL = ^phase_cnt_reg;
        endcase
    end

    always_comb begin
        state_next     = state;
        i2c_sr_next    = i2c_sr_reg;
        i2c_tdr_next   = i2c_tdr_reg;
        i2c_rdr_next   = i2c_rdr_reg;
        bit_cnt_next   = bit_cnt_reg;
        phase_cnt_next = phase_cnt_reg;
        scl_tick_clear = 1'b0;
        i2c_ready      = 1'b0;
        case (state)
            IDLE: begin
                scl_tick_clear = 1'b1;
                i2c_sr_next    = '0;
                if (i2c_en) begin
                    // scl_tick_clear = 1'b0;
                    state_next = START;
                end
            end
            HOLD: begin
                scl_tick_clear = 1'b1;
                i2c_ready      = 1'b1;
                if (i2c_trig) begin
                    i2c_sr_next.rx_done = 1'b0;
                    i2c_sr_next.tx_done = 1'b0;
                    // scl_tick_clear = 1'b0;
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
                if (scl_tick) begin
                    if (phase_cnt_reg == 3) begin
                        phase_cnt_next      = 0;
                        i2c_sr_next.st_done = 1'b1;
                        state_next          = HOLD;
                    end else begin
                        phase_cnt_next = phase_cnt_reg + 1;
                    end
                end
            end
            WRITE: begin
                if (scl_tick) begin
                    if (phase_cnt_reg == 3) begin
                        phase_cnt_next = 0;
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
                    end else begin
                        phase_cnt_next = phase_cnt_reg + 1;
                    end
                end
            end
            READ: begin
                if (scl_tick) begin
                    if (phase_cnt_reg == 1)
                        i2c_rdr_next = {i2c_rdr_reg[6:0], SDA};
                    if (phase_cnt_reg == 3) begin
                        phase_cnt_next = 0;
                        if (bit_cnt_reg == 7) begin
                            bit_cnt_next = 0;
                            state_next   = ACK_RW;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end else begin
                        phase_cnt_next = phase_cnt_reg + 1;
                    end
                end
            end
            ACK_RW: begin
                if (scl_tick) begin
                    if (phase_cnt_reg == 1 && !i2c_sr_reg.is_read)
                        i2c_sr_next.is_nack = SDA;
                    if (phase_cnt_reg == 3) begin
                        phase_cnt_next = 0;
                        i2c_sr_next.tx_done = ~i2c_sr_reg.is_read;
                        i2c_sr_next.rx_done = i2c_sr_reg.is_read;
                        state_next = (i2c_sr_reg.is_nack) ? STOP : HOLD;
                    end else begin
                        phase_cnt_next = phase_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                if (scl_tick) begin
                    if (phase_cnt_reg == 3) begin
                        phase_cnt_next = 0;
                        state_next     = IDLE;
                    end else begin
                        phase_cnt_next = phase_cnt_reg + 1;
                    end
                end
            end
        endcase
    end
endmodule

module tick_gen #(
    parameter FREQ = 100_000
) (
    input  logic clk,
    input  logic reset,
    input  logic scl_tick_clear,
    output logic scl_tick
);
    localparam SCL_CNT = (100_000_000 / FREQ) / 4;
    logic [$clog2(SCL_CNT)-1:0] scl_cnt;
    always_ff @(posedge clk, posedge reset) begin
        if (reset | scl_tick_clear) begin
            scl_cnt  <= 0;
            scl_tick <= 1'b0;
        end else begin
            if (scl_cnt == SCL_CNT - 1) begin
                scl_cnt  <= 0;
                scl_tick <= 1'b1;
            end else begin
                scl_cnt  <= scl_cnt + 1;
                scl_tick <= 1'b0;
            end
        end
    end
endmodule
