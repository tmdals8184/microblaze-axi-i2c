`timescale 1ns / 1ps

module i2c_slave (
    // global signal
    input  logic       clk,
    input  logic       reset,
    // internal signal
    input  logic [7:0] send_data,
    output logic [7:0] recv_data,
    // external signal
    inout  logic       SDA,
    input  logic       SCL
);
    localparam SLV_ADDR = 7'b1010_000;
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
        HOLD,
        SEND,
        RECV,
        ACK_SEND,
        ACK_RECV
    } state_t;
    state_t state, state_next;
    logic ack_reg, ack_next;
    logic state_req_reg, state_req_next;
    logic [7:0] recv_data_reg, recv_data_next;
    logic [7:0] send_data_reg, send_data_next;
    logic [2:0] bit_cnt_reg, bit_cnt_next;
    logic rdwr_reg, rdwr_next;
    wire addr_match = (recv_data_next[7:1] == SLV_ADDR) ? 1'b1 : 1'b0;

    assign recv_data = recv_data_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state         <= IDLE;
            ack_reg       <= ACK;
            state_req_reg <= 1'b1;
            recv_data_reg <= 0;
            send_data_reg <= 0;
            bit_cnt_reg   <= 0;
            rdwr_reg      <= 1'b0;
            sda_en_reg    <= 1'b0;
        end else begin
            state         <= state_next;
            ack_reg       <= ack_next;
            state_req_reg <= state_req_next;
            recv_data_reg <= recv_data_next;
            send_data_reg <= send_data_next;
            bit_cnt_reg   <= bit_cnt_next;
            rdwr_reg      <= rdwr_next;
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
            ACK_SEND: if (SCL) sda_out = (ack_reg == ACK) ? 1'b0 : 1'b1;
            SEND:     sda_out = send_data_reg[7];
        endcase
    end
    always_comb begin
        state_next     = state;
        state_req_next = state_req_reg;
        recv_data_next = recv_data_reg;
        send_data_next = send_data_reg;
        bit_cnt_next   = bit_cnt_reg;
        rdwr_next      = rdwr_reg;
        ack_next       = ack_reg;
        sda_en_next    = sda_en_reg;
        case (state)
            IDLE: begin
                if (SCL) begin
                    if (sda_negedge) begin
                        state_next = HOLD;
                    end
                end
            end
            HOLD: begin
                if (scl_sync && sda_negedge) begin
                    state_req_next = 1'b1;
                end else if (scl_sync && sda_posedge) begin
                    state_next = IDLE;
                end else if (scl_posedge) begin
                    bit_cnt_next   = 1'b1;
                    recv_data_next = {recv_data_reg[6:0], SDA};
                    if (state_req_reg) begin
                        state_req_next = 1'b0;
                        state_next     = ADDR;
                    end else state_next = RECV;
                end
            end
            ADDR: begin
                if (scl_posedge) begin
                    recv_data_next = {recv_data_reg[6:0], SDA};
                    if (bit_cnt_reg == 7) begin
                        bit_cnt_next = 0;
                        rdwr_next    = SDA;
                        state_next   = ACK_SEND;
                        ack_next     = (addr_match) ? ACK : NACK;
                    end else begin
                        bit_cnt_next = bit_cnt_reg + 1;
                    end
                end
            end
            ACK_SEND: begin
                if (scl_posedge) sda_en_next = 1'b1;
                if (scl_negedge) begin
                    sda_en_next = 1'b0;
                    if (state_req_reg) begin
                        state_req_next = 1'b0;
                        if (rdwr_reg) begin
                            send_data_next = send_data;
                            state_next     = SEND;
                        end else begin
                            state_next = HOLD;
                        end
                    end else begin
                        state_req_next = 1'b1;
                    end
                end
            end
            ACK_RECV: begin
                sda_en_next = 1'b0;
                if (scl_posedge) begin
                    ack_next = (SDA == NACK);
                end
                if (scl_negedge) begin
                    if (ack_reg == NACK) begin
                        state_next = IDLE;
                    end else begin
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
                if (scl_posedge) begin
                    recv_data_next = {recv_data_reg[6:0], SDA};
                    if (bit_cnt_reg == 7) begin
                        bit_cnt_next = 0;
                        ack_next     = ACK;
                        state_next   = ACK_SEND;
                    end else begin
                        bit_cnt_next = bit_cnt_reg + 1;
                    end
                end
            end
        endcase
    end

endmodule
