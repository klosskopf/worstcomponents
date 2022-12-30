// For std::unique_ptr
#include <memory>
#include <verilated.h>
#include "../obj_dir/Vtst_ram.h"

double sc_time_stamp() { return 0; }
void write(const std::unique_ptr<Vtst_ram>& ram, const std::unique_ptr<VerilatedContext>& contextp, uint32_t adr, uint32_t data);
uint32_t read(const std::unique_ptr<Vtst_ram>& ram, const std::unique_ptr<VerilatedContext>& contextp, uint32_t adr);

int main(int argc, char** argv, char** env)
{
    // Prevent unused variable warnings
    if (false && argc && argv && env) {}
    
    Verilated::mkdir("logs");
    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    contextp->randReset(2);// Randomization reset policy
    contextp->traceEverOn(true);
    contextp->commandArgs(argc, argv);

    const std::unique_ptr<Vtst_ram> ram{new Vtst_ram{contextp.get(), "RAM"}};

    for (int i =0; i< 1000; i++)
    {
        write(ram,contextp,i,i);
    }

    for (int i =0; i< 1000; i++)
    {
        assert(read(ram,contextp,i) == i);
     // read(ram,contextp,i);
    }

    ram->final();

    // Coverage analysis (calling write only after the test is known to pass)
#if VM_COVERAGE
    Verilated::mkdir("logs");
    contextp->coveragep()->write("logs/coverage.dat");
#endif
}

void write(const std::unique_ptr<Vtst_ram>& ram, const std::unique_ptr<VerilatedContext>& contextp, uint32_t adr, uint32_t data)
{
    ram->adr_i = adr;
    ram->dat_i = data;
    ram->we_i = 1;
    ram->sel_i = 0b1111;
    ram->stb_i = 1;
    ram->clk_i = 0;
    ram->eval();
    contextp->timeInc(1);
    assert(ram->ack_o == 1);
    ram->clk_i = 1;
    ram->eval();
    contextp->timeInc(1);
}

uint32_t read(const std::unique_ptr<Vtst_ram>& ram, const std::unique_ptr<VerilatedContext>& contextp, uint32_t adr)
{
    ram->adr_i = adr;   //Start the read transfer on the falling clock
    ram->we_i = 0;
    ram->sel_i = 0b1111;
    ram->stb_i = 1;
    ram->clk_i = 0;
    ram->eval();
    contextp->timeInc(1);

    assert(ram->ack_o == 0);    //The slave is not yet ready, this is read at the rising clock
    ram->clk_i = 1;
    ram->eval();
    contextp->timeInc(1);

    assert(ram->ack_o == 1);    //with the next falling cycle the slave announces the the data is now valid and can be read at the rising clock
    ram->clk_i = 0;
    ram->eval();
    contextp->timeInc(1);
        
    ram->clk_i = 1;             //read the data
    ram->eval();
    contextp->timeInc(1);
    
    return ram->dat_o;
}