`timescale 1ns/1ns

module tst_wbInterconnect (
    input clk_i,

    input [31:0] madr_i [1:0],
    output [31:0] mdat_o [1:0],
    input [31:0] mdat_i [1:0],
    input mwe_i [1:0],
    input [3:0] msel_i [1:0],
    input mstb_i [1:0],
    output mack_o [1:0],
    input mcyc_i [1:0],

    output [31:0] sadr_o [1:0],
    input [31:0] sdat_i [1:0],
    output [31:0] sdat_o [1:0],
    output swe_o [1:0],
    output [3:0] ssel_o [1:0],
    output sstb_o [1:0],
    input sack_i [1:0],
    output scyc_o [1:0]
);

wbInterconnect #(2, 2) top (
    .clk_i(clk_i),

    .madr_i(madr_i),
    .mdat_o(mdat_o),
    .mdat_i(mdat_i),
    .mwe_i(mwe_i),
    .msel_i(msel_i),
    .mstb_i(mstb_i),
    .mack_o(mack_o),
    .mcyc_i(mcyc_i),

    .sadr_o(sadr_o),
    .sdat_i(sdat_i),
    .sdat_o(sdat_o),
    .swe_o(swe_o),
    .ssel_o(ssel_o),
    .sstb_o(sstb_o),
    .sack_i(sack_i),
    .scyc_o(scyc_o)
);

initial begin
    $dumpfile("logs/vlt_dump.vcd");
    $dumpvars();
end

endmodule
