`ifndef SPI_V
`define SPI_V

`timescale 1ns/1ns
`include "fifo.v"

module spi (
    input clk_i,
    input rst_i,

    input [3:2] adr_i,
    input [3:0] sel_i,
    input stb_i,
    input we_i,
    input [31:0] dat_i,
    output reg [31:0] dat_o,
    output reg ack_o,

    output reg spiClk_o,
    output spiMosi_o,
    input spiMiso_i
);

parameter SPISPED = 5;

/*Recive-FIFO*/
reg [7:0] dataInRec;
reg pushDataRec;
wire [7:0] dataOutRec;
reg getDataRec;
wire [7:0] sizeRec;
fifo #(.WIDTH(8), .DEPTH(8)) recFifo(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .data_i(dataInRec),
    .setData_i(pushDataRec),
    .data_o(dataOutRec),
    .getData_i(getDataRec),
    .size_o(sizeRec)
);

/*Send-FIFO*/
reg [7:0] dataInSend;
reg pushDataSend;
wire [7:0] dataOutSend;
reg getDataSend;
wire [7:0] sizeSend;
fifo #(.WIDTH(8), .DEPTH(8)) sendFifo(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .data_i(dataInSend),
    .setData_i(pushDataSend),
    .data_o(dataOutSend),
    .getData_i(getDataSend),
    .size_o(sizeSend)
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
reg [31:0] registerOutputs [`REGISTERNR-1:0]; // the current output values of the registers. the registers themselve are done in custom code
reg [1:0] registerStatus [`REGISTERNR-1:0]; // The status wires of the resgisters. To be used by custom code
reg [$clog2(`REGISTERNR+1)-1:0] regSelect; 
integer i;
always @(*) begin
    regSelect = adr_i[$clog2(`REGISTERNR+1)+1:2]; //Find out witch register is addressed
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

//Data in and output
always @(*) begin
    pushDataSend = (registerStatus[0] == `REG_WRITE);
    getDataRec = (registerStatus[0] == `REG_READ);
    dataInSend = registerInput[7:0];
end
always @(*) begin
    registerOutputs[0] = {24'b0,dataOutRec};
end

//Statusregister
wire recFull;
wire recHalf;
wire recNew;
wire recEmpty;
wire sendFull;
wire busy;
wire [31:0] statusReg;
assign recFull = sizeRec[3];
assign recHalf = sizeRec[2];
assign recNew = |sizeRec;
assign recEmpty = ~recNew;
assign sendFull = sizeSend[3];
assign statusReg = {sizeSend,sizeRec,10'b0,busy,sendFull,recFull,recHalf,recNew,recEmpty};
always @(*) begin
    registerOutputs[1] = statusReg;
end

//SPI-Speed Register
reg [15:0] spiSped;
always @(posedge(clk_i),posedge(rst_i)) begin
    if (rst_i) spiSped <= SPISPED;
    else if (clk_i) begin
        if (registerStatus[2] == `REG_WRITE) spiSped <= registerInput[15:0];
    end
end
always @(*) begin
    registerOutputs[2] = {16'h0000,spiSped};
end

//spi statemachine
reg [3:0] state;
`define IDLE 0 //No clock
`define FIRST 1 //get new data to transmit from sendFifo
`define FINISH 8 //push data back in recFifo
reg [15:0] counter; //only do stuff when counter is 0
always @(posedge(rst_i),posedge(clk_i)) begin
    if (rst_i) begin
        state <= `IDLE;
        counter <= 16'd0;
    end
    else if (clk_i) begin
        case (state)
            `IDLE: begin
                if (|sizeSend) begin //If we are idle and there is data in sendFifo
                    state <= `FIRST; //Start with first bit
                    counter <= 16'd0; //and restart counter
                end
            end
            `FINISH: begin
                if (counter == spiSped) begin //counter overflow
                    counter <= 16'd0;
                    if (spiClk_o) begin // if spi_clk was high, we just transmitted the last bit
                        if (|sizeSend) state <= `FIRST; //If there is more, restart
                        else state <= `IDLE; // else go back to idle
                    end
                end
                else counter <= counter + 1'd1; //we are still in the middle of last bit
            end
            default: begin
                if (counter == spiSped) begin //If the counter finished
                    counter <= 16'd0;
                    if (spiClk_o) state <= state + 1'b1; //and the clk is high (last edge was positive), increment to the next bit
                end
                else counter <= counter + 1'd1;
            end
        endcase
    end
end

assign busy = (state != `IDLE);

//spi clock generation
reg spiClkEn;
always @(*) begin
    if ((state != `IDLE) & (counter == 16'd0)) spiClkEn = 1'b1;    //This signal is used by the rest, to find out if counter is 0 (its time to do something)
    else spiClkEn = 1'b0;                                         //and the SPI is running
end
always @(posedge(rst_i),posedge(clk_i)) begin
    if (rst_i) spiClk_o <= 1'b1; //start with clk high (like every civilised SPI should do)
    else if (clk_i) begin
        if (state != `IDLE) begin
            if (spiClkEn) spiClk_o <= !spiClk_o; // if the counter overfloweth, the clock toggles (you can see, that spiClkEn is active at both edges)
        end
        else spiClk_o <= 1'b1; //and return to 1 under all circumstances at the end (Probabbly not necessary)
    end
end

//misoReg
reg misoReg;
always @(posedge(clk_i)) begin
    if (clk_i) begin
        if (spiClkEn & !spiClk_o) misoReg <= spiMiso_i; //we want to sample miso at rising edge, but set the workregister at the falling edge, thus we buffer miso
    end
end

//workregister (from fifo to workregister)
reg [7:0] workreg;
always @(*) begin
    if ((state == `FIRST) & spiClkEn & spiClk_o) getDataSend = 1'b1; //At the first (falling) edge of bit one, we load the byte from fifo to the workregister
    else getDataSend = 1'b0;
end
always @(posedge(rst_i),posedge(clk_i)) begin
    if (rst_i) workreg <= 8'hxx;
    else if (clk_i) begin
        if (spiClkEn & spiClk_o) begin //only change workregister at falling edges
            if (state == `FIRST) workreg <= dataOutSend; //At the first one, get the data from fifo
            else workreg <= {workreg[6:0],misoReg}; //every other shifts the buffered miso in the lsb
        end
    end
end

//from workregister to mosi
assign spiMosi_o = workreg[7]; //...and the msb to mosi

//from workregister to fifo
always @(*) begin                           //because workdir is changed at the falling edges, but there is no falling edge after the last rising edge
    dataInRec = {workreg[6:0],spiMiso_i};//we do the last bitshift and miso sampling seperately
    if ((state == `FINISH) & spiClkEn & !spiClk_o) pushDataRec = 1'b1; //We do this at the last rising edge
    else pushDataRec = 1'b0;
end

endmodule

`endif //SPI_V
