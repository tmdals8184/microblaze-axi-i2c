`timescale 1ns / 1ps

module tb_i2c_master ();

    // global signal
    logic       m_clk;
    logic       m_reset;
    logic       s_clk;
    logic       s_reset;
    // mst internal signal
    logic       i2c_en;
    logic       i2c_trig;
    logic       i2c_start;
    logic       i2c_stop;
    logic       i2c_ack;
    logic [7:0] tx_data;
    logic       tx_done;
    logic       tx_ready;
    logic [7:0] rx_data;
    logic       rx_done;
    // slv internal signal
    logic [7:0] send_data;
    logic [7:0] recv_data;
    // external signal
    // wire        SDA = tb_sda_en ? tb_sda_out : 1'bz;
    wire       SDA;
    logic       SCL;
    // for verify
    logic       tb_sda_en;
    logic       tb_sda_out;

    i2c_master dut_mst (
        .clk  (m_clk),
        .reset(m_reset),
        .SDA  (SDA),
        .*
    );
    i2c_slave dut_slv (
        .clk  (s_clk),
        .reset(s_reset),
        .SDA  (SDA),
        .*
    );

    typedef enum logic [1:0] {
        WRITE,
        START,
        STOP,
        READ
    } set_e;
    typedef enum bit {
        ACK,
        NACK
    } ack_e;

    always #5 m_clk = ~m_clk;
    always #5 s_clk = ~s_clk;

    initial begin
        #00 m_clk = 0;
        s_clk = 1;
        m_reset = 1;
        s_reset = 1;
        tb_sda_en = 0;
        #10 m_reset = 0;
        #5 s_reset = 0;
    end

    initial begin
        repeat (5) @(posedge m_clk);
        mst_init();
        mst_send(WRITE, 8'hf0);
        // slv_send_ack(ACK);
    end

    task automatic mst_init();
        i2c_en = 1'b1;
        @(posedge m_clk);
        wait (tx_ready);
        @(posedge m_clk);
    endtask //automatic

    task automatic mst_send(set_e status, byte data = 8'hxx);
        wait (tx_ready);
        @(posedge m_clk);
        if (status == WRITE) begin
            tx_data = data;
            @(posedge m_clk);
        end
        i2c_trig = 1'b1;
        {i2c_stop, i2c_start} = status;
        @(posedge m_clk);
        i2c_trig = 1'b0;
        @(posedge m_clk);
    endtask  //automatic

    /*
    task automatic slv_send_ack(ack_e ack);
        wait (tx_done);
        @(posedge m_clk);
        $display("%t", $time);
        tb_sda_en  = 1'b1;
        tb_sda_out = ack;
        @(posedge m_clk);
        wait (tx_ready);
        tb_sda_en = 1'b0;
    endtask  //automatic
    */
endmodule
