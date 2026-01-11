`timescale 1ns / 1ps

module i2c_slave (
    // debug signal
    output logic [2:0] status,
    // global signal
    input  logic       clk,
    input  logic       reset,
    // internal signal
    input  logic [7:0] send_data,
    output logic [7:0] recv_data,
    output logic       send_done,
    output logic       recv_done,
    output logic       send_ready,
    output logic       is_send,
    // external signal
    inout  logic       SDA,
    input  logic       SCL
);
    localparam SLV_ADDR = 7'b101_0000;
    localparam ACK = 1'b0, NACK = 1'b1;

    /***** SDA 3state buf *****/
    logic sda_en_reg, sda_en_next, sda_out;
    assign SDA = sda_en_reg ? sda_out : 1'bz;

    /***** SDA, SCL synchronizer *****/
    logic [1:0] sda_sync, scl_sync;
    logic sda_sync_en_reg, sda_sync_en_next;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            sda_sync_en_reg <= 1'b1;
            sda_sync        <= 0;
            scl_sync        <= 0;
        end else begin
            sda_sync_en_reg <= sda_sync_en_next;
            if (sda_sync_en_reg) begin
                sda_sync <= {sda_sync[0], SDA};
            end else begin
                sda_sync <= 0;
            end
            scl_sync <= {scl_sync[0], SCL};
        end
    end

    wire sda_posedge = sda_sync[0] & ~sda_sync[1];
    wire sda_negedge = ~sda_sync[0] & sda_sync[1];
    wire scl_posedge = scl_sync[0] & ~scl_sync[1];
    wire scl_negedge = ~scl_sync[0] & scl_sync[1];

    /***** Slave In Sequence *****/
    typedef enum {
        IDLE,
        ADDR,
        RECV,
        ACK_SEND,
        SEND,
        ACK_RECV
    } state_t;
    state_t state, state_next;

    typedef struct packed {
        logic send_done;
        logic recv_done;
        logic sta_buf;
        logic is_read;
        logic is_addr;
        logic is_nack;
    } slv_stat_t;
    slv_stat_t slv_stat, slv_stat_next;

    logic [7:0] recv_data_reg, recv_data_next;
    logic [7:0] send_data_reg, send_data_next;
    logic [2:0] bit_cnt_reg, bit_cnt_next;

    wire addr_match = (recv_data_next[7:1] == SLV_ADDR) ? 1'b1 : 1'b0;

    assign recv_data = recv_data_reg;
    assign recv_done = slv_stat.recv_done;
    assign is_send   = slv_stat.is_read;

    /***** for debug *****/
    assign status    = state;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state         <= IDLE;
            slv_stat      <= '0;
            recv_data_reg <= 0;
            send_data_reg <= 0;
            bit_cnt_reg   <= 0;
            sda_en_reg    <= 1'b0;
        end else begin
            state         <= state_next;
            slv_stat      <= slv_stat_next;
            recv_data_reg <= recv_data_next;
            send_data_reg <= send_data_next;
            bit_cnt_reg   <= bit_cnt_next;
            sda_en_reg    <= sda_en_next;
        end
    end

    always_comb begin
        sda_sync_en_next = 1'b1;
        sda_out          = 1'b0;
        case (state)
            ACK_SEND, RECV: sda_sync_en_next = 1'b0;
        endcase
        case (state)
            ACK_SEND: sda_out = slv_stat.is_nack;
            SEND:     sda_out = send_data_reg[7];
        endcase
    end

    always_comb begin
        state_next              = state;
        slv_stat_next           = slv_stat;
        slv_stat_next.recv_done = 1'b0;
        slv_stat_next.send_done = 1'b0;
        recv_data_next          = recv_data_reg;
        send_data_next          = send_data_reg;
        bit_cnt_next            = bit_cnt_reg;
        sda_en_next             = sda_en_reg;

        if (scl_sync[0] && sda_posedge && state != IDLE) begin
            state_next            = IDLE;
            slv_stat_next.sta_buf = 1'b1;
            bit_cnt_next          = 0;
            sda_en_next           = 1'b0;
            recv_data_next        = 0;
        end else if (scl_sync[0] && sda_negedge && state != IDLE) begin
            state_next     = ADDR;
            bit_cnt_next   = 0;
            sda_en_next    = 1'b0;
            recv_data_next = 0;
        end else begin
            case (state)
                IDLE: begin
                    if (scl_sync[0] & sda_negedge) slv_stat_next.sta_buf = 1'b1;
                    if (slv_stat.sta_buf & scl_negedge) begin
                        slv_stat_next.sta_buf = 1'b0;
                        bit_cnt_next          = 0;
                        recv_data_next        = 0;
                        state_next            = ADDR;
                    end
                end
                ADDR: begin
                    if (scl_posedge) recv_data_next = {recv_data_reg[6:0], SDA};
                    if (scl_negedge) begin
                        if (bit_cnt_reg == 7) begin
                            bit_cnt_next            = 0;
                            slv_stat_next.recv_done = 1'b1;
                            slv_stat_next.is_read   = recv_data_next[0];
                            slv_stat_next.is_nack   = (addr_match) ? ACK : NACK;
                            state_next              = ACK_SEND;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end
                end
                ACK_SEND: begin
                    if (scl_posedge) sda_en_next = 1'b1;
                    if (scl_negedge) begin
                        sda_en_next = 1'b0;
                        if (slv_stat.is_nack) state_next = IDLE;
                        else if (slv_stat.is_read) begin
                            send_data_next = send_data;
                            state_next     = SEND;
                        end else state_next = RECV;
                    end
                end
                ACK_RECV: begin
                    sda_en_next = 1'b0;
                    if (scl_posedge) slv_stat_next.is_nack = SDA;
                    if (scl_negedge) begin
                        if (slv_stat.is_nack) state_next = IDLE;
                        else begin
                            send_data_next = send_data;
                            state_next     = SEND;
                        end
                    end
                end
                SEND: begin
                    sda_en_next = 1'b1;
                    if (scl_negedge) begin
                        send_data_next = {send_data_reg[6:0], 1'b0};
                        if (bit_cnt_reg == 7) begin
                            bit_cnt_next = 0;
                            state_next   = ACK_RECV;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end
                end
                RECV: begin
                    if (scl_posedge) recv_data_next = {recv_data_reg[6:0], SDA};
                    if (scl_negedge) begin
                        if (bit_cnt_reg == 7) begin
                            bit_cnt_next            = 0;
                            slv_stat_next.is_nack   = ACK;
                            slv_stat_next.recv_done = 1'b1;
                            state_next              = ACK_SEND;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end
                end
            endcase
        end
    end

endmodule
