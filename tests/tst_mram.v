`timescale 1ns/1ns

module tst_mram (
    input clk_i,
    input rst_i,
    input stb_i,
    input we_i,
    input [3:0] sel_i,
    input [31:0] dat_i,
    output reg [31:0] dat_o,
    input [29:0] adr_i,
    output ack_o,
    output reg spiCs_o,
    output reg spiClk_o,
    output reg spiMosi_o,
    input spiMiso_i
);

mram #(.SPISPED(1)) top(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .stb_i(stb_i),
    .we_i(we_i),
    .sel_i(sel_i),
    .dat_i(dat_i),
    .dat_o(dat_o),
    .adr_i(adr_i),
    .ack_o(ack_o),
    .spiCs_o(spiCs_o),
    .spiClk_o(spiClk_o),
    .spiMosi_o(spiMosi_o),
    .spiMiso_i(spiMiso_i)
);

initial begin
    $dumpfile("logs/vlt_dump.vcd");
    $dumpvars();
end
    
endmodule
