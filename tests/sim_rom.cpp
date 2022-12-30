// For std::unique_ptr
#include <memory>
#include <verilated.h>
#include "../obj_dir/Vtst_rom.h"

double sc_time_stamp() { return 0; }

int main(int argc, char** argv, char** env)
{
    // Prevent unused variable warnings
    if (false && argc && argv && env) {}
    
    Verilated::mkdir("logs");
    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    contextp->randReset(2);// Randomization reset policy
    contextp->traceEverOn(true);
    contextp->commandArgs(argc, argv);

    const std::unique_ptr<Vtst_rom> rom{new Vtst_rom{contextp.get(), "ROM"}};
    rom->rst_i = 1;
    rom->clk_i = 1;
    rom->adr_i = 0;
    rom->stb_i = 0;
    
    while (!contextp->gotFinish() && contextp->time() < 20)
    {
        if (contextp->time() == 2) rom->rst_i = 0;
        if (contextp->time() == 6) rom->stb_i = 1;
        rom->adr_i = contextp->time();

        rom->clk_i ^= 1;
        rom->eval();
        contextp->timeInc(1);
    }

    rom->final();

    // Coverage analysis (calling write only after the test is known to pass)
#if VM_COVERAGE
    Verilated::mkdir("logs");
    contextp->coveragep()->write("logs/coverage.dat");
#endif
}
