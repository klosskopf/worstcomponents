`timescale 1ns/1ns

module uart (
    input clk_i,
    input rst_i,

    input stb_i,
    input we_i,
    input [3:2] adr_i,
    input [3:0] sel_i,
    input [31:0] dat_i,
    output reg [31:0] dat_o,
    output reg ack_o,

    output reg uartTx_o,
    input uartRx_i
);
parameter UARTSPED = 16'd269; //baud = fsys / uartSped

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
wire recFull; //The receive buffer is full
wire recHalf; //The receive buffer is half full
wire recNew; //There is stuff in the receive buffer
wire recEmpty; //There is no stuff in the receive buffer
wire sendFull; //The send buffer is full
wire busy; //The uart is transmitting
assign recFull = sizeRec[3];
assign recHalf = sizeRec[2];
assign recNew = |sizeRec;
assign recEmpty = ~recNew;
assign sendFull = sizeSend[3];
wire [31:0] statusReg;
assign statusReg = {sizeSend,sizeRec,10'b0,busy,sendFull,recFull,recHalf,recNew,recEmpty};
always @(*) begin
    registerOutputs[1] = statusReg;
end

//UART-Baud Register
reg [15:0] uartSped;
always @(posedge(clk_i),posedge(rst_i)) begin
    if (rst_i) uartSped <= UARTSPED;
    else if (clk_i) begin
        if (registerStatus[2] == `REG_WRITE) uartSped <= registerInput[15:0];
    end
end
always @(*) begin
    registerOutputs[2] = {16'h0000,uartSped};
end

//uart tx statemachine
reg [3:0] txState;
`define IDLE 0 //No clock
`define START 1 //get new data to transmit from sendFifo
`define STOP 10 //push data back in recFifo
reg [15:0] txCounter; //only do stuff when counter is 0
always @(posedge(rst_i),posedge(clk_i)) begin
    if (rst_i) begin
        txState <= `IDLE;
        txCounter <= 16'b0;
    end
    else if (clk_i) begin
        case (txState)
            `IDLE: begin
                if (|sizeSend) begin //If we are idle and there is data in sendFifo
                    txState <= `START; //Start with start bit
                    txCounter <= 16'b0; //and restart counter
                end
            end
            `STOP: begin
                if (txCounter == uartSped) begin //counter overflow
                    txCounter <= 16'b0;
                    if (|sizeSend) txState <= `START; //Immediately start with next startbit
                    else txState <= `IDLE; //Or get back to idle, if fifo is empty
                end
                else txCounter <= txCounter + 1'b1; //we are still in the middle of stop bit
            end
            default: begin
                if (txCounter == uartSped) begin //If the counter finished
                    txCounter <= 16'b0;
                    txState <= txState + 1'b1; //get on to the next clock
                end
                else txCounter <= txCounter + 1'b1; //we are still in the middle of the bit
            end
        endcase
    end
end

assign busy = (txState != `IDLE);

//workregister (from fifo to workregister)
reg [7:0] txWorkreg;
always @(*) begin
    if ((txState == `START) & (txCounter == uartSped)) getDataSend = 1'b1; //at end of start bit: get new data from fifo
    else getDataSend = 1'b0;
end
always @(posedge(rst_i),posedge(clk_i)) begin
    if (rst_i) txWorkreg <= 8'hxx;
    else if (clk_i) begin
        case (txState)
            `IDLE: txWorkreg <= 8'hxx;
            `START: begin
                if (txCounter == uartSped) txWorkreg <= dataOutSend; //and put it in the workregister
            end 
            `STOP: txWorkreg <= 8'hxx;
            default: begin
                if (txCounter == uartSped) txWorkreg <= {1'b0,txWorkreg[7:1]}; //shift the workregister, so the tx bit is always at bit 0
            end
        endcase
    end
end

//from workregister to tx
always @(*) begin
    case (txState)
        `IDLE: uartTx_o = 1'b1; //IDLE state is high
        `START: uartTx_o = 1'b0; //start bit is low
        `STOP: uartTx_o = 1'b1; //stop bit is high
        default: uartTx_o = txWorkreg[0]; //because we shift the workregister, tx is always bit 0
    endcase
end

//buffered rx, to detect edges
//reg rxOld;
//wire rxNegedge;
//assign rxNegedge = rxOld & !uartRx_i;
//always @(posedge(clk_i)) begin
//    if (clk_i) rxOld <= uartRx_i; 
//end

reg [3:0] rxState;
reg [15:0] rxCounter;
`define DONE 11
always @(posedge(clk_i),posedge(rst_i)) begin
    if (rst_i) begin
        rxState <= `IDLE;
        rxCounter <= 16'h0;
    end
    else if (clk_i) begin
        case (rxState)
            `IDLE: begin
                if (!uartRx_i) begin //We only sync once per byte. On the falling edge of the start bit. This may be sloppy, but who cares
                    rxState <= `START;
                    rxCounter <= 16'h0;
                end
            end 
            `STOP: begin
                if (uartRx_i) rxState <= `DONE; //Get to idle asap (at start of the incoming stop bit), to catch next falling edge, even if slightly out of sync
                rxCounter <= 16'h0;
            end
            `DONE: begin
                rxState <= `IDLE;
            end
            default: begin
                if (rxCounter == uartSped) begin //Its as stupid as it sounds. Just count the bits with a timer
                    rxCounter <= 16'h0;
                    rxState <= rxState + 1'b1;
                end
                else rxCounter <= rxCounter + 1'b1;
            end
        endcase
    end
end

//rxWorkregister
reg [7:0] rxWorkreg;
always @(posedge(rst_i),posedge(clk_i)) begin
    if (rst_i) rxWorkreg <= 8'h0;
    else if (clk_i) begin
        case (rxState)
            `IDLE: rxWorkreg <= 8'hxx;
            `START: rxWorkreg <= 8'h0; //Could also be xx
            `STOP,`DONE: rxWorkreg <= rxWorkreg; //We need to hold the workreg, because now we put it in the recFifo
            default: begin
                if (rxCounter == uartSped/16'h2) rxWorkreg <= {uartRx_i,rxWorkreg[7:1]}; //If the counter is in the middle of a bit, sample it
            end
        endcase
    end
end

//from workregister to fifo
always @(*) begin
    dataInRec = rxWorkreg;
    if (rxState == `DONE) pushDataRec = 1'b1; //Because stop-rx-state is only one clock, unlike the stop bit, we can use it as is for the push signal
    else pushDataRec = 1'b0;
end

endmodule
