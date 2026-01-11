`timescale 1ns / 1ps

module fnd_controller (
    input  logic        clk,
    input  logic        reset,
    input  logic [13:0] cnt_data,
    output logic [ 3:0] fnd_com,
    output logic [ 7:0] fnd_seg
);
    localparam MAX = 10_000;

    // wire
    logic [3:0] digit_1, digit_10, digit_100, digit_1000;
    logic [ 3:0] bcd;
    logic [ 1:0] sel;
    wire  [13:0] decimal_data = cnt_data;

    counter #(
        .COUNT(4),
        .FREQ (1_000)
    ) U_CNT_4 (
        .*,
        .runstop(1'b1),
        .clear(1'b0),
        .cnt_data(sel)
    );
    digit_splitter #(.MAX(MAX)) U_DS (.*);
    mux_4x1 U_MUX_4x1 (.*);
    decoder_2x4 U_DEC_2x4 (.*);
    bcd_decoder U_BCD_DEC (.*);



endmodule

module mux_4x1 (
    input  [3:0] digit_1,
    input  [3:0] digit_10,
    input  [3:0] digit_100,
    input  [3:0] digit_1000,
    input  [1:0] sel,
    output [3:0] bcd
);

    reg [3:0] r_bcd;
    assign bcd = r_bcd;

    always @(*) begin
        case (sel)
            2'b00:   r_bcd = digit_1;
            2'b01:   r_bcd = digit_10;
            2'b10:   r_bcd = digit_100;
            2'b11:   r_bcd = digit_1000;
            default: r_bcd = digit_1;
        endcase
    end

endmodule

module decoder_2x4 (
    input  [1:0] sel,
    output [3:0] fnd_com
);

    reg [3:0] r_fnd_com;
    assign fnd_com = r_fnd_com;

    always @(*) begin
        case (sel)
            2'b00:   r_fnd_com = 4'b1110;
            2'b01:   r_fnd_com = 4'b1101;
            2'b10:   r_fnd_com = 4'b1011;
            2'b11:   r_fnd_com = 4'b0111;
            default: r_fnd_com = 4'b1111;
        endcase
    end

endmodule

module digit_splitter #(
    parameter MAX = 10_000
) (
    input  [$clog2(MAX)-1:0] decimal_data,
    output [            3:0] digit_1,
    output [            3:0] digit_10,
    output [            3:0] digit_100,
    output [            3:0] digit_1000
);

    assign digit_1    = decimal_data % 10;
    assign digit_10   = (decimal_data / 10) % 10;
    assign digit_100  = (decimal_data / 100) % 10;
    assign digit_1000 = (decimal_data / 1000) % 10;

endmodule

module bcd_decoder (
    input  [3:0] bcd,
    output [7:0] fnd_seg
);

    reg [7:0] r_fnd_seg;
    assign fnd_seg = r_fnd_seg;

    always @(*) begin
        case (bcd)
            4'h0:    r_fnd_seg = 8'hc0;
            4'h1:    r_fnd_seg = 8'hf9;
            4'h2:    r_fnd_seg = 8'ha4;
            4'h3:    r_fnd_seg = 8'hb0;
            4'h4:    r_fnd_seg = 8'h99;
            4'h5:    r_fnd_seg = 8'h92;
            4'h6:    r_fnd_seg = 8'h82;
            4'h7:    r_fnd_seg = 8'hf8;
            4'h8:    r_fnd_seg = 8'h80;
            4'h9:    r_fnd_seg = 8'h90;
            4'ha:    r_fnd_seg = 8'h88;
            4'hb:    r_fnd_seg = 8'h83;
            4'hc:    r_fnd_seg = 8'hc6;
            4'hd:    r_fnd_seg = 8'ha1;
            4'he:    r_fnd_seg = 8'h86;
            4'hf:    r_fnd_seg = 8'h8e;
            default: r_fnd_seg = 8'hff;
        endcase
    end

endmodule

