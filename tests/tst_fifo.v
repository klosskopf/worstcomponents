`include "fifo.v"
`timescale 1ns/1ns

module tst_fifo (
    input clk_i,
    input rst_i,
    input [7:0] data_i,
    input setData_i,
    output [7:0] data_o,
    input getData_i,
    output reg [3:0] size_o
);
fifo #(.DEPTH(4), .WIDTH(8)) top(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .data_i(data_i),
    .setData_i(setData_i),
    .data_o(data_o),
    .getData_i(getData_i),
    .size_o(size_o)
);

initial begin
    $dumpfile("logs/vlt_dump.vcd");
    $dumpvars();
end
    
endmodule
