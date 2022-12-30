`include "rom.v"
`timescale 1ns/1ns

module tst_rom (
    input clk_i,
    input rst_i,
    input [29:0] adr_i,
    output [31:0] dat_o,
    input stb_i,
    output ack_o
);

rom top(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .adr_i(adr_i),
    .dat_o(dat_o),
    .stb_i(stb_i),
    .ack_o(ack_o)
);

initial begin
    $dumpfile("logs/vlt_dump.vcd");
    $dumpvars();
end
    
endmodule
