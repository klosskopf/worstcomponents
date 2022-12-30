`timescale 1ns/1ns

https://github.com/zachjs/sv2v


module wbInterconnect #(
    parameter MASTERNR = 1,
    parameter SLAVENR = 1
)(
    input clk_i,

    input [31:0] madr_i [MASTERNR-1:0],
    output reg [31:0] mdat_o [MASTERNR-1:0],
    input [31:0] mdat_i [MASTERNR-1:0],
    input mwe_i [MASTERNR-1:0],
    input [3:0] msel_i [MASTERNR-1:0],
    input mstb_i [MASTERNR-1:0],
    output reg mack_o [MASTERNR-1:0],
    input mcyc_i [MASTERNR-1:0],

    output reg [31:0] sadr_o [SLAVENR-1:0],
    input [31:0] sdat_i [SLAVENR-1:0],
    output reg [31:0] sdat_o [SLAVENR-1:0],
    output reg swe_o [SLAVENR-1:0],
    output reg [3:0] ssel_o [SLAVENR-1:0],
    output reg sstb_o [SLAVENR-1:0],
    input sack_i [SLAVENR-1:0],
    output reg scyc_o [SLAVENR-1:0]
);

reg cyc;
reg stb;
reg we;
reg [3:0] sel;
reg [31:0] datMosi;
reg [31:0] datMiso;
reg [31:0] adr;
reg ack;
reg acmp [SLAVENR-1:0];
reg gnt [MASTERNR-1:0];

//Slave inputs
always @(*) begin
    for (int i = 0; i<SLAVENR; i+=1) begin
        sadr_o[i] = adr;
        sdat_o[i] = datMosi;
        ssel_o[i] = sel;
        swe_o[i] = we;
        scyc_o[i] = cyc;
        sstb_o[i] = acmp[i] & cyc & stb;
    end
end

//0x0000_0000 - 0x1FFF_FFFF: BootROM
//0x2000_0000 - 0x3FFF_FFFF: IO
//0x4000_0000 - 0x7FFF_FFFF: RAM
//0x8000_0000 - 0xFFFF_FFFF: FRAM?
always @(*) begin
    for (int i = 0; i<SLAVENR; i+=1) begin
        acmp[i] = 1'b0;
    end
    if (adr[31:29] == 3'b000) acmp[0] = 1'b1;//ROM
    else if (adr[31:30] == 2'b01) acmp[1] = 1'b1;//RAM
end

//Slave outputs
always @(*) begin
    datMiso = 32'hxxxxxxxx;
    ack = 1'b0;
    for (int i = 0; i<SLAVENR; i+=1) begin
        if (acmp[i]) begin
            datMiso = sdat_i[i];
            ack |= sack_i[i];
        end
    end
end

//Master inputs
always @(*) begin
    for (int i = 0; i<MASTERNR; i+=1) begin
        if (gnt[i]) begin
            mdat_o[i] = datMiso;
            mack_o[i] = ack;
        end
        else begin
            mdat_o[i] = 32'hxxxxxxxx;
            mack_o[i] = 1'b0;
        end
    end
end

//Master output
always @(*) begin
    adr = 32'hxxxxxxxx;
    datMosi = 32'hxxxxxxxx;
    sel = 4'hx;
    we = 1'b0;
    stb = 1'b0;
    cyc = 1'b0;
    for (int i = 0; i<MASTERNR; i+=1) begin
        if (gnt[i]) begin
            adr = madr_i[i];
            datMosi = mdat_i[i];
            sel = msel_i[i];
            we = mwe_i[i];
            stb = mstb_i[i];
            cyc = 1'b1;
        end
    end
end

reg busFree;
always @(*) begin
    busFree = 1'b1;
    for (int i = 0; i<MASTERNR; i+=1) begin
        if (mcyc_i[i] && gnt[i])    //if a master has been granted access and is not finished yet,
            busFree = 1'b0;         //the bus is not free
    end
end
reg [MASTERNR:0] accessPrio;   //Each bit says, that this or a higher prio master wants access
always @(*) begin
    accessPrio[0] = mcyc_i[0];
    for (int i = 1; i<MASTERNR; i+=1) begin
        accessPrio[i] = mcyc_i[i] | accessPrio[i-1];
    end
end
always @(posedge(clk_i)) begin
    if (clk_i) begin
        if (busFree)                           //If a new master is searched for
            gnt[0] <= mcyc_i[0];                        //highest priority master can be it if it wants
        else
            gnt[0] <= gnt[0];
        for (int i = 1; i < MASTERNR; i+=1) begin
            if (busFree) begin                 //If a new master is searched for
                if (accessPrio[i] && !accessPrio[i-1])  //if the master wants access and has priority (The higher prio master has accessPrio low)
                    gnt[i] <= 1'b1;                     //Take the access;
                else
                    gnt[i] <= 1'b0;
            end                                         //else nothing changes
            else
                gnt[i] <= gnt[i];
        end
    end
end

endmodule
