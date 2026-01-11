`timescale 1ns / 1ps

module master_top #(
    parameter F_BTN = 1_000,
    parameter F_CNT = 10
) (
    input  logic clk,
    input  logic reset,
    input  logic btnL,
    input  logic btnR,
    output logic sclk,
    output logic mosi,
    input  logic miso,
    output logic cs
);
    logic [13:0] cnt_data;
    logic [ 7:0] tx_data;
    logic        start;
    logic        tx_ready;
    logic        done;
    logic        btn_clear;
    logic        btn_runstop;

    button_debounce #(
        .F_BTN(F_BTN)
    ) U_BD_L (
        .*,
        .i_btn(btnL),
        .o_btn(btn_clear)
    );
    button_debounce #(
        .F_BTN(F_BTN)
    ) U_BD_R (
        .*,
        .i_btn(btnR),
        .o_btn(btn_runstop)
    );

    up_counter #(.FREQ(F_CNT)) U_UpCounter (.*);
    spi_packer U_SPIPacker (.*);    
    spi_master U_SPIMaster (
        .*,
        .cpol(1'b0),
        .cpha(1'b0),
        .rx_data()
    );
endmodule
