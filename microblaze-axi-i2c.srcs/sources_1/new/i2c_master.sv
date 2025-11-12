`timescale 1ns / 1ps

module i2c_master (
    // global signal
    input  logic       clk,
    input  logic       reset,
    // internal signal
    input  logic       i2c_en,
    input  logic       i2c_start,
    input  logic       i2c_stop,
    input  logic       i2c_ack,
    input  logic [7:0] tx_data,
    output logic       tx_done,
    output logic       tx_ready,
    output logic [7:0] rx_data,
    output logic       rx_done,
    // external signal
    inout  logic       SDA,
    output logic       SCL
);

    typedef enum {
        IDLE,
        HOLD,
        START,
        STOP,
        WRITE,
        READ,
        ACK_WR,
        ACK_RD
    } state_t;
    state_t state, state_next;
    logic sda_en, sda_out;
    logic [7:0] tx_data_reg, tx_data_next;
    logic [7:0] rx_data_reg, rx_data_next;
    logic [8:0] clk_cnt_reg, clk_cnt_next;
    logic [2:0] bit_cnt_reg, bit_cnt_next;
    logic [1:0] phase_cnt_reg, phase_cnt_next;
    logic ack_reg, ack_next;

    assign SDA = sda_en ? sda_out : 1'bz;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state         <= IDLE;
            tx_data_reg   <= 0;
            rx_data_reg   <= 0;
            clk_cnt_reg   <= 0;
            bit_cnt_reg   <= 0;
            phase_cnt_reg <= 0;
            ack_reg       <= 0;
        end else begin
            state          <= state_next;
            tx_data_reg    <= tx_data_next;
            rx_data_reg    <= rx_data_next;
            clk_cnt_reg    <= clk_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
            phase_cnt_next <= phase_cnt_next;
            ack_reg        <= ack_next;
        end
    end

    always_comb begin
        SCL = 1'b1;
        case (state)
            IDLE:  SCL = 1'b1;
            HOLD:  SCL = 1'b0;
            START: SCL = (phase_cnt_reg) ? 1'b0 : 1'b1;
            STOP:  SCL = (phase_cnt_reg) ? 1'b1 : 1'b0;
            WRITE, READ, ACK_WR, ACK_RD: begin
                case (phase_cnt_reg)
                    2'd0, 2'd3: SCL = 1'b0;
                    2'd1, 2'd2: SCL = 1'b1;
                endcase
            end
        endcase
    end

    always_comb begin
        state_next     = state;
        tx_data_next   = tx_data_reg;
        rx_data_next   = rx_data_reg;
        clk_cnt_next   = clk_cnt_reg;
        bit_cnt_next   = bit_cnt_reg;
        phase_cnt_next = phase_cnt_reg;
        ack_next       = ack_reg;
        sda_en         = 1'b1;
        sda_out        = 1'b1;
        tx_done        = 1'b0;
        tx_ready       = 1'b0;
        rx_done        = 1'b0;
        case (state)
            IDLE: begin
                sda_en   = 1'b1;
                sda_out  = 1'b1;
                tx_ready = 1'b1;
                if (i2c_en) begin
                    state_next = HOLD;
                end
            end
            HOLD: begin
                tx_ready = 1'b1;
                sda_en   = 1'b1;
                sda_out  = 1'b1;
                if (i2c_en) begin
                    case ({
                        i2c_start, i2c_stop
                    })
                        2'b00: begin  // write
                            tx_data_next = tx_data;
                            sda_out      = tx_data[7];
                            state_next   = WRITE;
                        end
                        2'b01: begin  // stop
                            state_next = STOP;
                        end
                        2'b10: begin  // start
                            sda_out    = 1'b1;
                            SCL        = 1'b1;
                            state_next = START;
                        end
                        2'b11: begin  // read
                            state_next = READ;
                        end
                    endcase
                end
            end
            START: begin
                sda_en  = 1'b1;
                sda_out = 1'b0;
                if (clk_cnt_reg == 499) begin
                    clk_cnt_next = 0;
                    if (phase_cnt_reg == 1) begin
                        phase_cnt_next = 0;
                        state_next     = HOLD;
                    end else begin
                        phase_cnt_next = phase_cnt_reg + 1;
                    end
                end else begin
                    clk_cnt_next = clk_cnt_reg + 1;
                end
            end
            WRITE: begin
                sda_en  = 1'b1;
                sda_out = tx_data_reg[7];
                if (clk_cnt_reg == 249) begin
                    clk_cnt_next = 0;
                    if (phase_cnt_reg == 3) begin
                        phase_cnt_next = 0;
                        if (bit_cnt_reg == 7) begin
                            bit_cnt_next = 0;
                            state_next   = ACK_WR;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                            tx_data_next = {tx_data_reg[6:0], 1'b0};
                        end
                    end else begin
                        phase_cnt_next = phase_cnt_reg + 1;
                    end
                end else begin
                    clk_cnt_next = clk_cnt_reg + 1;
                end
            end
            ACK_WR: begin
                sda_en = 1'b0;
                if (clk_cnt_reg == 249) begin
                    clk_cnt_next = 0;
                    if (phase_cnt_reg == 1) ack_next = SDA;
                    if (phase_cnt_reg == 3) begin
                        phase_cnt_next = 0;
                        tx_done        = 1'b1;
                        state_next     = (ack_reg) ? STOP : HOLD;
                    end else begin
                        phase_cnt_next = phase_cnt_reg + 1;
                    end
                end else begin
                    clk_cnt_next = clk_cnt_reg + 1;
                end
            end
            READ: begin
                sda_en = 1'b0;
                if (clk_cnt_reg == 249) begin
                    clk_cnt_next = 0;
                    if (phase_cnt_reg == 1)
                        rx_data_next = {rx_data_reg[6:0], SDA};
                    if (phase_cnt_reg == 3) begin
                        phase_cnt_next = 0;
                        if (bit_cnt_reg == 7) begin
                            bit_cnt_next = 0;
                            rx_done      = 1'b1;
                            state_next   = ACK_RD;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end else begin
                        phase_cnt_next = phase_cnt_reg + 1;
                    end
                end else begin
                    clk_cnt_next = clk_cnt_reg + 1;
                end
            end
            ACK_RD: begin
                sda_en  = 1'b1;
                sda_out = (i2c_ack) ? 1'b0 : 1'b1;
                if (clk_cnt_reg == 249) begin
                    clk_cnt_next = 0;
                    if (phase_cnt_reg == 3) begin
                        phase_cnt_next = 0;
                        state_next     = ack_reg ? STOP : HOLD;
                    end
                    if (phase_cnt_reg == 1) begin
                        phase_cnt_next = phase_cnt_reg + 1;
                        ack_next = SDA;
                    end else begin
                        phase_cnt_next = phase_cnt_reg + 1;
                    end
                end else begin
                    clk_cnt_next = clk_cnt_reg + 1;
                end
            end
            STOP: begin
                sda_en  = 1'b1;
                sda_out = 1'b0;
                if (clk_cnt_reg == 499) begin
                    clk_cnt_next = 0;
                    if (phase_cnt_reg == 1) begin
                        phase_cnt_next = 0;
                        state_next = WRITE;
                    end else begin
                        phase_cnt_next = phase_cnt_reg + 1;
                    end
                end else begin
                    clk_cnt_next = clk_cnt_reg + 1;
                end
            end
        endcase
    end
endmodule
