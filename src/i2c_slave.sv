`timescale 1ns / 1ps

module i2c_slave (
    // global signal
    input logic clk,
    input logic reset,
    // internal signal
    input logic [7:0] send_data,
    output logic [7:0] recv_data,
    // external signal
    inout logic SDA,
    input logic SCL
);
    localparam SLV_ADDR = 7'b101000;

    /***** SDA synchronizer *****/
    logic [1:0] sda_sync, scl_sync;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            sda_sync <= 0;
            scl_sync <= 0;
        end else begin
            sda_sync <= {sda_sync[0], SDA};
            scl_sync <= {scl_sync[0], SCL};
        end
    end

    wire sda_posedge = sda_sync[0] & ~sda_sync[1];
    wire sda_negedge = ~sda_sync[0] & sda_sync[1];
    wire scl_posedge = scl_sync[0] & ~scl_sync[1];
    wire scl_negedge = ~scl_sync[0] & scl_sync[1];

    /***** SDA 3state buf *****/
    logic sda_en_reg, sda_en_next, sda_out;
    assign SDA = sda_en_reg ? sda_out : 1'bz;

    /***** Slave In Sequence *****/
    typedef enum {
        IDLE,
        ADDR,
        SEND,
        RECV,
        ACK_SEND,
        ACK_RECV
    } state_t;
    state_t state, state_next;
    logic [7:0] recv_data_reg, recv_data_next;
    logic [2:0] bit_cnt_reg, bit_cnt_next;
    logic rdwr_reg, rdwr_next;
    logic ack_reg, ack_next;
    wire addr_match = (recv_data_reg[7:1] == SLV_ADDR) ? 1'b1 : 1'b0;

    assign recv_data = recv_data_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state         <= IDLE;
            recv_data_reg <= 0;
            bit_cnt_reg   <= 0;
            rdwr_reg      <= 1'b0;
            ack_reg       <= 1'b0;
            sda_en_reg    <= 1'b0;
        end else begin
            state         <= state_next;
            recv_data_reg <= recv_data_next;
            bit_cnt_reg   <= bit_cnt_next;
            rdwr_reg      <= rdwr_next;
            ack_reg       <= ack_next;
            sda_en_reg    <= sda_en_next;
        end
    end

    always_comb begin
        state_next     = state;
        recv_data_next = recv_data_reg;
        bit_cnt_next   = bit_cnt_reg;
        rdwr_next      = rdwr_reg;
        ack_next       = ack_reg;
        sda_en_next    = sda_en_reg;
        sda_out        = 1'b0;
        case (state)
            IDLE: begin
                if (SCL) begin
                    if (sda_negedge) begin
                        state_next = ADDR;
                    end
                end
            end
            ADDR: begin
                if (scl_posedge) begin
                    recv_data_next = {recv_data_reg[6:0], SDA};
                    if (bit_cnt_reg == 7) begin
                        bit_cnt_next = 0;
                        rdwr_next    = SDA;
                        ack_next     = addr_match;
                        state_next   = ACK_SEND;
                    end else begin
                        bit_cnt_next = bit_cnt_reg + 1;
                    end
                end
            end
            ACK_SEND: begin
                if (SCL) begin
                    sda_out = (ack_reg) ? 1'b0 : 1'b1;
                end
                if (scl_posedge) begin
                    sda_en_next = 1'b1;
                end
                if (scl_negedge) begin
                    sda_en_next = 1'b0;
                    state_next  = RECV;
                end
            end
            ACK_RECV: begin

            end
            SEND: begin

            end
            RECV: begin
                if (scl_posedge) begin
                    recv_data_next = {recv_data_reg[6:0], SDA};
                    if (bit_cnt_reg == 7) begin
                        bit_cnt_next = 0;
                        ack_next     = 1'b0;
                        state_next   = ACK_SEND;
                    end else begin
                        bit_cnt_next = bit_cnt_reg + 1;
                    end
                end
            end
        endcase
    end

endmodule
