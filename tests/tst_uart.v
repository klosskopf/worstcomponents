`timescale 1ns/1ns

module tst_uart (
    input clk_i,
    input rst_i,

    input [1:0] adr_i,
    input [3:0] sel_i,
    input stb_i,
    input we_i,
    input [31:0] dat_i,
    output reg [31:0] dat_o,
    output ack_o,

    output reg uartTx_o,
    input uartRx_i
);

uart top(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .adr_i(adr_i),
    .sel_i(sel_i),
    .stb_i(stb_i),
    .we_i(we_i),
    .dat_i(dat_i),
    .dat_o(dat_o),
    .ack_o(ack_o),
    .uartTx_o(uartTx_o),
    .uartRx_i(uartRx_i)
);

initial begin
    $dumpfile("logs/vlt_dump.vcd");
    $dumpvars();
end
    
endmodule
