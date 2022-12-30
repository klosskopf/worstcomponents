`ifndef MRAM_V
`define MRAM_V

`timescale 1ns/1ns

module mram (
    input clk_i,
    input rst_i,
    input stb_i,
    input we_i,
    input [3:0] sel_i,
    input [31:0] dat_i,
    output [31:0] dat_o,
    input [29:0] adr_i,
    output reg ack_o,

    output reg spiCs_o,
    output reg spiClk_o,
    output reg spiMosi_o,
    input spiMiso_i
);

parameter SPISPED = 2;
parameter ADDRESSBITS = 16;

//The Nr of bits that should be read/written from/to mram
reg [5:0] nextBitNr; 
always @(*) begin
    if (we_i) begin
        case (sel_i)
            4'b1111: nextBitNr = 6'd32; //4 bytes shall be written
            4'b0011,4'b1100: nextBitNr = 6'd16; //2bytes
            4'b0001,4'b0010,4'b0100,4'b1000: nextBitNr = 6'd8; //1 byte
            default: nextBitNr = 6'dx; //yeah this is ilegal with wishbone; optimize
        endcase
    end
    else begin
        nextBitNr = 6'd32; //Always read 4 bytes no mater if needed. this makes life easier
    end
end
//The start address. Gets offset, if sel indicates non alligned writes
reg [ADDRESSBITS-1:0] nextAddress;
always @(*) begin
    if (we_i) begin
        case (sel_i) //adr_i is word addressed
            4'b1111,4'b0011,4'b0001: nextAddress = {adr_i[ADDRESSBITS-3:0],2'b00}; //left bit is byte0 => no offset
            4'b0010: nextAddress = {adr_i[ADDRESSBITS-3:0],2'b01}; //byte1 is first mem cell => 1byte offset
            4'b0100,4'b1100: nextAddress = {adr_i[ADDRESSBITS-3:0],2'b10}; //byte 2 is first mem cell
            4'b1000: nextAddress = {adr_i[ADDRESSBITS-3:0],2'b11}; //byte3 is first mem cell
            default: nextAddress = {ADDRESSBITS{1'bx}}; //Not allowed with wishbone. Let optimize
        endcase
    end
    else begin
        nextAddress = {adr_i[ADDRESSBITS-3:0],2'b00}; //Because we always read 4 bytes, no need to add a offset 
    end
end
//The shifted data input
reg [31:0] nextDataIn;
always @(*) begin
    case (sel_i) //gets evaluated from left to right! => shuffle bytes; not all transfered bytes are used (depends on sel_i)
        4'b1111,4'b0011,4'b0001: nextDataIn = {dat_i[7:0],dat_i[15:8],dat_i[23:16],dat_i[31:24]}; //start with byte0
        4'b0010: nextDataIn = {dat_i[15:8],24'hxxxxxx}; //start with byte 2
        4'b0100,4'b1100: nextDataIn = {dat_i[23:16],dat_i[31:24],16'hxxxx}; //start with byte3
        4'b1000: nextDataIn = {dat_i[31:24],24'hxxxxxx}; //start with byte4 and only 4
        default: nextDataIn = 32'hxxxxxxxx;
    endcase
end
//store details at transfer cycle
reg [ADDRESSBITS-1:0] address;
reg [31:0] dataIn;
reg [5:0] bitNr;
always @(posedge(clk_i)) begin
    if (clk_i) begin
        if (stb_i) begin
            address <= nextAddress;
            dataIn <= nextDataIn;
            bitNr <= nextBitNr;
        end
    end
end

//states of mram module
`define IDLE 0 //Wait for a transaction
`define READ 1 //Perform a read
`define WRITEEN 2 //enable a write
`define WRITE 3 //follows WRITEEN
reg [7:0] state;
reg [7:0] oldState;
reg spiDone;
always @(posedge(clk_i), posedge(rst_i)) begin
    if (rst_i) begin
        state <= `IDLE;
        oldState <= `IDLE;
    end
    else if (clk_i) begin
        oldState <= state; //Used to detect state changes
        case (state)
            `IDLE: begin
                if (stb_i && we_i) state <= `WRITEEN; //only the we_ bit differentiates between writes and reads
                else if (stb_i && !we_i) state <= `READ;
            end
            `READ: begin
                if (spiDone) state <= `IDLE; //The spi subsystem ends a read
            end
            `WRITEEN: begin
                if (spiDone) state <= `WRITE; //And a write
            end
            `WRITE: begin
                if (spiDone) state <= `IDLE; //''
            end
            default: state <= `IDLE;
        endcase
    end
end

//one clk pulse to start a spi transfer
reg spiStart; //Starts a spi transfer (data in spiPackage; length in bits in spiPackageSize)
always @(*) begin
    if (oldState != state) begin //If a statechange happened
        case (state)
            `READ,`WRITEEN,`WRITE: spiStart = 1'b1; //And we are not in IDLE, start a transfer
            default: spiStart = 1'b0;
        endcase
    end
    else spiStart = 1'b0;
end

//ack
always @(*) begin
    ack_o = 1'b0;
    case (state)
        `READ,`WRITE: begin //When we are in READ or WRITE State ...
            if (spiDone) ack_o = 1'b1; //.. and the spi subsystem reports a finished frame
        end                             //the transaction is done
        default: ack_o = 1'b0;
    endcase
end

//Assamble a spi frame
reg [ADDRESSBITS+39:0] spiPackage; //
always @(*) begin
    case (state) //READ WRITEEN and Write have different frame structures/content
        `READ: spiPackage = {8'h03,address,32'hxxxxxxxx}; //The frame is bitwise evaluated from left
        `WRITEEN: spiPackage = {8'h06,{(ADDRESSBITS+32){1'bx}}}; //If the frame is smaller than 56 bit the
        `WRITE: spiPackage = {8'h02,address,dataIn}; //rest is filled with don`t care
        default: spiPackage = {ADDRESSBITS+40{1'bx}}; //Lets hope we never land here. Who knows what could happen
    endcase
end
//How many bits should be transmitted in the current frame
reg [6:0] spiPackageSize; //This is mostly needed because a write is parted in two frames (writeen;write)
always @(*) begin
    case (state)
        `READ: spiPackageSize = 7'd8 + ADDRESSBITS + bitNr; //8bit command + 16bit address + 32bit read
        `WRITEEN: spiPackageSize = 7'd8; //8bit commmand
        `WRITE: spiPackageSize = 7'd8 + ADDRESSBITS + bitNr; //8bit command + 16bit address + 8/16/32bit write
        default: spiPackageSize = 7'hx;
    endcase
end

//SPI state machine
`define SPI_IDLE 0 //Wait for a frame to be transmitted
`define SPI_TRANSMIT 1 //Transmit date
`define SPI_DONE 2 //Finished, make report with spiDone
reg [2:0] spiState; //Another state machine !?!
reg [6:0] spiCounter; //counting the transmitting bit
reg spiClkEn; //mask the cycle changing the spiClk
always @(posedge(rst_i), posedge(clk_i)) begin
    if (rst_i) begin 
        spiState <= `SPI_IDLE;
    end
    else if (clk_i) begin
        case (spiState)
            `SPI_IDLE: begin
                if (spiStart) spiState <= `SPI_TRANSMIT; //spiStart starts a transaction
            end
            `SPI_TRANSMIT: begin //one spiClk cyle is over and all bits are sent
                if (spiClkEn && spiClk_o && (spiCounter == spiPackageSize)) spiState <= `SPI_DONE;
            end
            `SPI_DONE: spiState <= `SPI_IDLE; //Immediately return to idle, so the spiDone is only one clk high
            default: spiState <= `SPI_IDLE;
        endcase
    end
end

//spi clock generation
reg [7:0] spiClkCounter; //counting the time in transmit state; We don't want to send spi with sysclk
always @(posedge(clk_i)) begin
    if (clk_i) begin
        case (spiState)
            `SPI_IDLE: spiClkCounter <= 8'h0; //start at 0 => trigger at  first clk in TRANSMIT
            `SPI_TRANSMIT: begin
                if (spiClkCounter == SPISPED) spiClkCounter <= 8'h0; //Overflow => reset
                else spiClkCounter <= spiClkCounter + 1'b1;
            end 
            default: spiClkCounter <= 8'hxx; //whatever
        endcase
    end
end
always @(*) begin
    if ((spiState == `SPI_TRANSMIT) && (spiClkCounter == 8'h0)) spiClkEn = 1'b1; //This signal is used by the rest, to find out if counter is 0 (its time to do something)
    else spiClkEn = 1'b0;
end
reg spiClk; //Intermediate spi clk
always @(posedge(clk_i)) begin
    if (clk_i) begin
        if (spiState == `SPI_TRANSMIT) begin //only clock when transmitting a frame
            if (spiClkEn) spiClk <= !spiClk; 
        end
        else spiClk <= 1'b1; //and return to 1 under all circumstances
    end
end
always @(*) begin //Now mask this clock with the TRANSMIT STATE (This only fixes a small bug. Don't worry about it)
    if (spiState == `SPI_TRANSMIT) spiClk_o = spiClk;
    else spiClk_o = 1'b1;
end

//counting spi-bits
always @(posedge(clk_i)) begin
    if (clk_i) begin
        case (spiState)
            `SPI_IDLE: spiCounter <= 7'd0; //This gets instantantly changed in TRANSMIT state
            `SPI_TRANSMIT: if (spiClkEn && spiClk_o) spiCounter <= spiCounter + 1'b1; //Increase at negative edge
            default: spiCounter <= 7'hx;
        endcase
    end
end

//CS logic
always @(*) begin
    if (spiState == `SPI_TRANSMIT) spiCs_o = 1'b0;
    else spiCs_o = 1'b1;
end

//mosi logic
reg [ADDRESSBITS+39:0] mosiReg;
always @(posedge(clk_i)) begin
    if (clk_i) begin
        if (spiClkEn && spiClk_o) begin //only change workregister at falling edges
            if (spiCounter == 7'd0) mosiReg <= spiPackage; //At first falling edge load the new frame in another register
            else mosiReg <= {mosiReg[ADDRESSBITS+38:0],1'bx}; //on every other shift the data out
        end
    end
end
always @(*) begin
    case (spiState)
        `SPI_TRANSMIT: spiMosi_o = mosiReg[ADDRESSBITS+39]; //also mask the mosi output 
        default: spiMosi_o = 1'b0;
    endcase
end

//misologic
reg [31:0] misoReg; //Doesn't matter that this can't hold afull frame. data is at end
always @(posedge(clk_i)) begin
    if (clk_i) begin
        if (spiClkEn && !spiClk_o) begin //only change workregister at rising edges
            misoReg <= {misoReg[30:0], spiMiso_i};
        end
    end
end
assign dat_o = {misoReg[7:0],misoReg[15:8],misoReg[23:16],misoReg[31:24]}; //shuffle data in little endian

//spiDone
always @(*) begin
    if (spiState == `SPI_DONE) spiDone = 1'b1;
    else spiDone = 1'b0;
end

endmodule

`endif //MRAM_V
