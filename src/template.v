`ifndef TEMPLATE_V
`define TEMPLATE_V

`timescale 1ns/1ns

module template (
    input clk_i,
    input rst_i,

    input stb_i,
    input we_i,
    input [31:2] adr_i,
    input [3:0] sel_i,
    input [31:0] dat_i,
    output reg [31:0] dat_o,
    output reg ack_o
);


`define REGISTERNR 3
//Acknowledge transfer
always @(*) begin
    ack_o = 1'bx;
    if (stb_i) begin //Here you can define when a transaction is done. In this case: In the same clock cycle
        ack_o = 1'b1;
    end
end
//register demutex
`define REG_IDLE 2'b00
`define REG_WRITE 2'b01
`define REG_READ 2'b10
reg [31:0] registerInput;
wire [31:0] registerOutputs [`REGISTERNR-1:0]; // the current output values of the registers. the registers themselve are done in custom code
reg [1:0] registerStatus [`REGISTERNR-1:0]; // The status wires of the resgisters. To be used by custom code
reg [$clog2(`REGISTERNR+1)-1:0] regSelect;
integer i;
always @(*) begin
    regSelect = adr_i[$clog2(`REGISTERNR+1)+1:2]; //Find out witch regiuster is addressed
    for (i = 0; i < `REGISTERNR; i = i+1 ) begin //Default outputs for all other registers
        dat_o = 32'hxxxxxxxx;
        registerStatus[i] = `REG_IDLE;
        registerInput = 32'hxxxxxxxx;
    end
    if (stb_i && !we_i) begin //read a register
        dat_o = registerOutputs[regSelect];
        registerStatus[regSelect] = `REG_READ;
    end
    else if (stb_i && we_i) begin //write a register
        registerInput[31:24] = sel_i[3] ? dat_i[31:24] : registerOutputs[regSelect][31:24];
        registerInput[23:16] = sel_i[2] ? dat_i[23:16] : registerOutputs[regSelect][23:16];
        registerInput[15:8]  = sel_i[1] ? dat_i[15:8]  : registerOutputs[regSelect][15:8];
        registerInput[7:0]   = sel_i[0] ? dat_i[7:0]   : registerOutputs[regSelect][7:0];
        registerStatus[regSelect] = `REG_WRITE;
    end
end

//Custom code from here on

reg [31:0] reg1;
always @(posedge(clk_i),posedge(rst_i)) begin
    if (rst_i) reg1 <= 32'h12345678;
    else if (clk_i) begin
        if (registerStatus[0] == `REG_WRITE) reg1 <= registerInput; //map the input of register #0 to reg1
    end
end
assign registerOutputs[0] = reg1; //map the output of register #0 to reg1

reg [31:0] reg2;
always @(posedge(clk_i),posedge(rst_i)) begin
    if (rst_i) reg2 <= 32'h03051996;
    else if (clk_i) begin
        if (registerStatus[1] == `REG_WRITE) reg2 <= registerInput;
    end
end
assign registerOutputs[1] = reg2;

reg [31:0] reg3;
always @(posedge(clk_i),posedge(rst_i)) begin
    if (rst_i) reg3 <= 32'hDEADDEAD;
    else if (clk_i) begin
        if (registerStatus[2] == `REG_WRITE) reg3 <= registerInput;
    end
end
assign registerOutputs[2] = reg3;

endmodule

`endif //TEMPLATE_V
