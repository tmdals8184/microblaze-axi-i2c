`ifndef I2C_SVH
`define I2C_SVH 

typedef enum {
    IDLE,
    START,
    HOLD,
    ADDR,
    AD_ACK,
    WRITE,
    WR_ACK,
    READ,
    RD_ACK,
    STOP
} m_state_t;

typedef struct packed {
    logic [10:0] res;
    logic        swrst;  // Bit 4: Software Reset       
    logic        ack;    // Bit 3: Acknowledge          (mack)
    logic        stop;   // Bit 2: Gen Stop             (stop)
    logic        start;  // Bit 1: Gen Start            (start)
    logic        pe;     // Bit 0: Peripheral Enable    (en)
} i2c_cr1_t;

typedef struct packed {
    logic [6:0] res;     // Bits 15-9  
    logic       itbufen; // Bit 8: Interrupt Buffer Enable
    logic       itevten; // Bit 7: Interrupt Event Enable
    logic       iterren; // Bit 6: Interrupt Error Enable
    logic [5:0] freq;    // Bits 5-0
} i2c_cr2_t;

typedef struct packed {
    logic [8:0] res;
    logic       af;   // Bit 6: Acknowledge Failure     (is_nack)
    logic       berr; // Bit 5: Bus Error
    logic       txe;  // Bit 4: Data Register Empty     (tx_done)
    logic       rxne; // Bit 3: Data Register Not Empty (rx_done)
    logic       btf;  // Bit 2: Byte Transfer Finished
    logic       addr; // Bit 1: Address Sent            (is_addr)
    logic       sb;   // Bit 0: Start Bit               (st_done)
} i2c_sr1_t;

typedef struct packed {
    logic [12:0] res;
    logic        msl;  // Bit 2: Master/Slave
    logic        busy; // Bit 1
    logic        tra;  // Bit 0: Transmitter/Receiver   (is_read)
} i2c_sr2_t;

typedef struct packed {
    logic cr_wr;
    logic cr_rd;
    logic sr_rd;
    logic dr_wr;
    logic dr_rd;
} i2c_bus_req_t;

// typedef struct packed {
//     logic sb_set;
//     logic addr_set;
// } i2c_core_cmd_t;

// typedef struct packed {
//     logic sb_set;
//     logic addr_set;    
// } i2c_core_evt_t;


`endif
