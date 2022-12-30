`timescale 1ns/1ns

module rom (
    input clk_i,
    input rst_i,
    input [29:0] adr_i,
    output reg [31:0] dat_o,
    input stb_i,
    output reg ack_o
);

parameter ROMADDRBITS = 13;
parameter FILE = "tests/firmware.mem";
    
reg [31:0] memory [(1<<ROMADDRBITS)-1:0];

always @(posedge(clk_i), posedge (rst_i)) begin
    if (rst_i) ack_o <= 1'b0;
    else if (clk_i) begin
        ack_o <= stb_i && !ack_o;
    end
end

always @(posedge(clk_i)) begin
    if (clk_i) begin
        dat_o <= memory[adr_i[ROMADDRBITS-1:0]];
    end
end

initial begin
    $readmemh(FILE, memory);
end

endmodule
