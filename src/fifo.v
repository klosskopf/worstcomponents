`timescale 1ns/1ns

module fifo #(
    parameter DEPTH = 7,
    parameter WIDTH = 8
)(
    input clk_i,
    input rst_i,
    input [WIDTH-1:0] data_i,
    input setData_i,
    output [WIDTH-1:0] data_o,
    input getData_i,
    output reg [DEPTH-1:0] size_o //No idea how to do this properly
);

reg [WIDTH-1:0] fifo [DEPTH-1:0];
reg [DEPTH-1:0] used_o;
reg [WIDTH-1:0] fifoPassthrough [DEPTH-1:0];


integer i;

//Next data to read is always at pos 0; passthrough is used in case the fifo is empty and read/write at the same time
assign data_o = fifoPassthrough[0];

//New data is passed through to the lowest free register
always @(*) begin
    if (used_o[DEPTH-1]) fifoPassthrough[DEPTH-1] = fifo[DEPTH-1]; //If the fifo level is used, passthrough is set to the value in this level
    else fifoPassthrough[DEPTH-1] = data_i; //Else the passthrough data from above is used, or in case of the highest level, the data input
    for (i=DEPTH-2 ; i>=0; i=i-1) begin
        if (used_o[i]) fifoPassthrough[i] = fifo[i];
        else fifoPassthrough[i] = fifoPassthrough[i+1];
    end

end
//usage monitoring
always @(posedge(rst_i),posedge(clk_i)) begin
    if (rst_i) begin
        used_o <= {DEPTH{1'b0}}; //size shows for every level, if it holds value
        size_o <= {DEPTH{1'b0}}; //size is only a counter to return usage
    end
    else if (clk_i) begin
        case ({setData_i,getData_i})
            2'b01: begin //only read data
                for ( i=0; i<DEPTH-1; i=i+1) begin
                    if (used_o[i] && !used_o[i+1]) used_o[i] <= 1'b0; //the index 0 is freed and higher levels ripple down
                end
                used_o[DEPTH-1] <= 1'b0; //the highest level is now always free
                if (size_o != 0) size_o <= size_o-1'b1;
            end
            2'b10: begin // only write data
                for ( i=1; i<DEPTH; i=i+1) begin
                    if (!used_o[i] && used_o[i-1]) used_o[i] <= 1'b1; //If the level is free, but the level below is used, this level is now also used
                end
                used_o[0] <= 1'b1; //When we write new data, the lowest level is definitly used now
                if (size_o != DEPTH) size_o <= size_o+1'b1;
            end
            default: used_o <= used_o; //If there is no access, or simultanious read/write, the usage does not change
        endcase 
    end
end

always @(posedge(clk_i)) begin
    if (clk_i) begin
        case ({setData_i,getData_i})
            2'b11: begin //read/write at the same time
                for (i = 0; i<DEPTH-1 ; i=i+1) begin
                    fifo[i] <= fifoPassthrough[i+1]; //get the next value from the passthrough line
                end
                fifo[DEPTH-1] <= data_i;
            end 
            2'b01: begin
                for (i = 0; i<DEPTH-1 ; i=i+1) begin
                    fifo[i] <= fifoPassthrough[i+1];
                end
                fifo[DEPTH-1] <= {WIDTH{1'bx}}; //if you only read from buffer, I don't care what is loaded in top; This is output if more reads than writes
            end
            2'b10: begin
                for (i = 0; i<DEPTH-1 ; i=i+1) begin
                    if (!used_o[i]) fifo[i] <= fifoPassthrough[i+1]; //only get the next value from the passthrough line, if you are currently not in use
                end
                if (!used_o[DEPTH-1]) fifo[DEPTH-1] <= data_i; //if the buffer is already full, the new data is lost
           end
           default: begin //No read/write
               for (i = 0; i<DEPTH; i=i+1) begin //This is just neccesary, to please yosys. All hail/prey to yosys
                   fifo[i] <= fifo[i];
               end
           end
       endcase 
    end
end
    
endmodule
