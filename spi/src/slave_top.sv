`timescale 1ns / 1ps

module slave_top (
    input  logic       clk,
    input  logic       reset,
    input  logic       sclk,
    input  logic       mosi,
    output logic       miso,
    input  logic       cs,
    output logic [3:0] fnd_com,
    output logic [7:0] fnd_seg
);
    logic [ 7:0] si_data;
    logic        si_done;
    logic [13:0] cnt_data;

    spi_slave U_SPISlave (
        .*,
        .so_data(),
        .so_start(),
        .so_ready()
    );
    spi_unpacker U_SPI_Unpacker (
        .*,
        .valid()
    );
    fnd_controller U_FND_CNTL (.*);
endmodule
