`include "ram.v"
`timescale 1ns/1ns

module tst_ram (
    input clk_i,
    input rst_i,
    input stb_i,
    input we_i,
    input [3:0] sel_i,
    input [31:0] dat_i,
    output reg [31:0] dat_o,
    input [29:0] adr_i,
    output ack_o
);

ram top(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .stb_i(stb_i),
    .we_i(we_i),
    .sel_i(sel_i),
    .dat_i(dat_i),
    .dat_o(dat_o),
    .adr_i(adr_i),
    .ack_o(ack_o)
);

initial begin
    $dumpfile("logs/vlt_dump.vcd");
    $dumpvars();
end
    
endmodule
