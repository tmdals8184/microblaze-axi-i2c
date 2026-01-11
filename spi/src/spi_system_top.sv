`timescale 1ns / 1ps

module spi_system_top (
    // global
    input  logic       clk,
    input  logic       reset,
    // i/o
    input  logic       btnL,
    input  logic       btnR,
    output logic [3:0] fnd_com,
    output logic [7:0] fnd_seg,
    // master
    output logic       m_sclk,
    output logic       m_mosi,
    input  logic       m_miso,
    output logic       m_cs,
    // slave
    input  logic       s_sclk,
    input  logic       s_mosi,
    output logic       s_miso,
    input  logic       s_cs
);
    master_top U_MST (
        .*,
        .sclk(m_sclk),
        .mosi(m_mosi),
        .miso(m_miso),
        .cs  (m_cs)
    );
    slave_top U_SLV (
        .*,
        .sclk(s_sclk),
        .mosi(s_mosi),
        .miso(s_miso),
        .cs  (s_cs)
    );
endmodule

