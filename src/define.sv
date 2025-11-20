    typedef struct packed {
        logic tx_done;
        logic rx_done;
        logic st_done;
        logic mst_rdy;
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
    } mst_state_t;
