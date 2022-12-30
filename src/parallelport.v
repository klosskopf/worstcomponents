`timescale 1ns/1ns

module parallelport (
    input clk_i,
    input rst_i,

    input [0:0] adr_i,
    input stb_i,
    input we_i,
    input [3:0] sel_i,
    input [31:0] dat_i,
    output reg [31:0] dat_o,
    output ack_o,

    output reg [31:0] parallel_o,
    input [31:0] parallel_i
);
assign ack_o = stb_i;

always @(*) begin
    if (adr_i[0]) dat_o = parallel_i; // offset 4 returns the input pins
    else dat_o = parallel_o;          // no offset returns current output pins
end

always @(posedge(clk_i), posedge(rst_i)) begin
    if (rst_i) parallel_o <= 32'h00000000;
    else if (clk_i) begin //For some reason yosys doesn't want clk_i in the stb_i,we_i if block 
        if (stb_i && we_i) begin
            if (sel_i[0])
                parallel_o[7:0] <= dat_i[7:0];
            if (sel_i[1])
                parallel_o[15:8] <= dat_i[15:8];
            if (sel_i[2])
                parallel_o[23:16] <= dat_i[23:16];
            if (sel_i[3])
                parallel_o[31:24] <= dat_i[31:24];
        end
    end
end

endmodule
