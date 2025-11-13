`timescale 1ns / 1ps

module tb_i2c_master ();

    // global signal
    logic       clk;
    logic       reset;
    // internal signal
    logic       i2c_en;
    logic       i2c_start;
    logic       i2c_stop;
    logic       i2c_ack;
    logic [7:0] tx_data;
    logic       tx_done;
    logic       tx_ready;
    logic [7:0] rx_data;
    logic       rx_done;
    // for verify
    logic       tb_sda_en;
    logic       tb_sda_out;
    // external signal
    wire        SDA = tb_sda_en ? tb_sda_out : 1'bz;
    logic       SCL;


    i2c_master dut_mst (.*);

    always #5 clk = ~clk;

    initial begin
        #00 clk = 0;
        reset = 1;
        tb_sda_en = 0;
        #10 reset = 0;
    end

    initial begin
        repeat (5) @(posedge clk);
        i2c_en    = 1'b1;
        i2c_start = 1'b1;
        i2c_stop  = 1'b0;

    end

endmodule
