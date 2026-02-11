`timescale 1ns / 1ps
`include "i2c_pkg.svh"

module i2c_master (
    // global signal
    input  logic           clk,
    input  logic           reset,
    // internal signal
    input  i2c_cr1_t       cr1,
    input  i2c_cr2_t       cr2,
    output i2c_sr1_t       sr1,
    output i2c_sr2_t       sr2,
    input  logic     [7:0] tdr,
    output logic     [7:0] rdr,
    // external signal
    inout  logic           SDA,
    output logic           SCL
);
    m_state_t state, state_next;
    i2c_sr1_t sr1_next;
    i2c_sr2_t sr2_next;
    logic sda_en, sda_out, scl_en, scl_out;
    logic [7:0] tx_buf_reg, tx_buf_next;
    logic [7:0] rx_buf_reg, rx_buf_next;
    logic [2:0] bit_cnt_reg, bit_cnt_next;
    logic [1:0] phase_cnt_reg;
    logic clear, tick;

    tick_gen #(
        .FREQ(100_000 / 4)
    ) U_TICK_GEN (
        .*,
        .clear(clear),
        .tick (tick)
    );

    always_ff @(posedge clk) begin
        if (reset || clear) begin
            phase_cnt_reg <= 0;
        end else if (tick && state != IDLE) begin
            phase_cnt_reg <= phase_cnt_reg + 1;
        end
    end

    assign SDA = (sda_en && !sda_out) ? 1'bz : 1'b0;
    assign SCL = (scl_en && !scl_out) ? 1'bz : 1'b0; 
    assign rdr = rx_buf_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset || !cr1.pe) begin
            state       <= IDLE;
            sr1         <= '0;
            sr2         <= '0;
            tx_buf_reg  <= 0;
            rx_buf_reg  <= 0;
            bit_cnt_reg <= 0;
        end else begin
            state       <= state_next;
            sr1         <= sr1_next;
            sr2         <= sr2_next;
            tx_buf_reg  <= tx_buf_next;
            rx_buf_reg  <= rx_buf_next;
            bit_cnt_reg <= bit_cnt_next;
        end
    end

    always_comb begin
        sda_en  = 1'b0;
        sda_out = 1'b0;
        scl_out = 1'b0;
        case (state)
            READ: sda_en = 1'b1;
        endcase
        case (state)
            IDLE:   sda_out = 1'b1;
            START:  sda_out = 1'b0;
            STOP:   sda_out = phase_cnt_reg[1];
            WRITE:  sda_out = tx_buf_reg[7];
            ACK_RW: sda_out = sr1.af;
        endcase
        case (state)
            IDLE, STOP:          scl_out = 1'b1;
            START:               scl_out = ~phase_cnt_reg[1];
            WRITE, READ, ACK_RW: scl_out = ^phase_cnt_reg;
        endcase
    end

    always_comb begin
        state_next   = state;
        sr1_next     = sr1;
        sr2_next     = sr2;
        tx_buf_next  = tx_buf_reg;
        rx_buf_next  = rx_buf_reg;
        bit_cnt_next = bit_cnt_reg;
        clear        = 1'b0;
        case (state)
            IDLE: begin
                clear    = 1'b1;
                sr1_next = '0;
                if (cr1.start) begin
                    // clear = 1'b0;
                    state_next = START;
                end
            end
            START: begin
                if (tick) begin
                    if (phase_cnt_reg == 3) begin
                        sr1_next.sb = 1'b1;
                        state_next  = ADDR;
                    end
                end
            end
            ADDR: begin

            end
            // HOLD: begin
            //     clear = 1'b1;
            //     if (cr1.start) begin
            //         sr1_next.busy = 1'b1;
            //         sr1_next.rxne = 1'b0;
            //         sr1_next.txe  = 1'b0;
            //         // clear = 1'b0;
            //         case ({
            //             cr1.start, cr1.stop
            //         })
            //             2'b00: begin
            //                 tx_buf_next  = tdr;
            //                 sr2_next.tra = 1'b0;
            //                 state_next   = WRITE;
            //             end
            //             2'b01: begin
            //                 state_next = STOP;
            //             end
            //             2'b10: begin
            //                 state_next = START;
            //             end
            //             2'b11: begin
            //                 sr2_next.tra = 1'b1;
            //                 sr1_next.af  = cr1.ack;
            //                 state_next   = READ;
            //             end
            //         endcase
            //     end
            // end
            WRITE: begin
                if (tick) begin
                    if (phase_cnt_reg == 3) begin
                        if (bit_cnt_reg == 7) begin
                            bit_cnt_next = 0;
                            if (sr1.sb) begin
                                sr1_next.sb   = 1'b0;
                                sr1_next.addr = 1'b1;
                            end else sr1_next.addr = 1'b0;
                            state_next = ACK_RW;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                            tx_buf_next  = {tx_buf_reg[6:0], 1'b0};
                        end
                    end
                end
            end
            READ: begin
                if (tick) begin
                    if (phase_cnt_reg == 1)
                        rx_buf_next = {rx_buf_reg[6:0], SDA};
                    if (phase_cnt_reg == 3) begin
                        if (bit_cnt_reg == 7) begin
                            bit_cnt_next = 0;
                            state_next   = ACK_RW;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end
                end
            end
            ACK_RW: begin
                if (tick) begin
                    if (phase_cnt_reg == 1 && !sr2.tra) sr1_next.af = SDA;
                    if (phase_cnt_reg == 3) begin
                        sr1_next.txe  = ~sr2.tra;
                        sr1_next.rxne = sr2.tra;
                        state_next    = (sr1.af) ? STOP : HOLD;
                    end
                end
            end
            STOP: begin
                if (tick) begin
                    if (phase_cnt_reg == 3) begin
                        state_next = IDLE;
                    end
                end
            end
        endcase
    end
endmodule

