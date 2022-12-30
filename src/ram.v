`timescale 1ns/1ns

module ram (
    input clk_i,
    input rst_i,
    input stb_i,
    input we_i,
    input [3:0] sel_i,
    input [31:0] dat_i,
    output reg [31:0] dat_o,
    input [29:0] adr_i,
    output reg ack_o
);

parameter RAMADDRBITS = 15;

wire writeAck;
reg readAck;

reg [31:0] memory [(1<<RAMADDRBITS)-1:0];

assign writeAck = stb_i && we_i;

always @(posedge(clk_i), posedge (rst_i)) begin
    if (rst_i) readAck <= 1'b0;
    else if (clk_i) begin
        readAck <= stb_i && !we_i && !readAck;
    end
end

always @(*) begin
    if (we_i) ack_o = writeAck;
    else ack_o = readAck;
end

always @(posedge(clk_i)) begin
    if (clk_i) begin
        dat_o <= memory[adr_i[RAMADDRBITS-1:0]];
    end
end

always @(posedge(clk_i)) begin
    if (clk_i) begin
        if (stb_i && we_i) begin
            if (sel_i[0])
                memory[adr_i[RAMADDRBITS-1:0]][7:0] <= dat_i[7:0];
            if (sel_i[1])
                memory[adr_i[RAMADDRBITS-1:0]][15:8] <= dat_i[15:8];
            if (sel_i[2])
                memory[adr_i[RAMADDRBITS-1:0]][23:16] <= dat_i[23:16];
            if (sel_i[3])
                memory[adr_i[RAMADDRBITS-1:0]][31:24] <= dat_i[31:24];
        end
    end
end

endmodule
