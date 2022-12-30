// For std::unique_ptr
#include <memory>
#include <verilated.h>
#include "../obj_dir/Vtst_mram.h"

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

    const std::unique_ptr<Vtst_mram> mram{new Vtst_mram{contextp.get(), "MRAM"}};

    mram->ack_o = 0;
    mram->adr_i = 1;
    mram->clk_i = 1;
    mram->rst_i = 1;
    mram->sel_i = 0b0010;
    mram->stb_i = 0;
    mram->we_i = 0;
    mram->dat_i = 0x01020304;
    mram->spiMiso_i = 0;
    
    while(contextp->time() < 1000)
    {
        if (contextp->time() == 2) mram->rst_i = 0;
        if (contextp->time() == 4) mram->stb_i = 1;
        if (contextp->time() == 458) mram->stb_i = 0;
        if (contextp->time() == 257) mram->spiMiso_i = 1;
        if (contextp->time() == 265) mram->spiMiso_i = 0;
        if (contextp->time() == 313) mram->spiMiso_i = 1;
        if (contextp->time() == 321) mram->spiMiso_i = 0;
        if (contextp->time() == 377) mram->spiMiso_i = 1;
        if (contextp->time() == 393) mram->spiMiso_i = 0;
        if (contextp->time() == 433) mram->spiMiso_i = 1;
        if (contextp->time() == 441) mram->spiMiso_i = 0;
        if (contextp->time() == 458) mram->stb_i = 0;

        if (contextp->time() == 500) mram->we_i = 1, mram->stb_i = 1;
        if (contextp->time() == 832) mram->stb_i = 0;


        mram->clk_i ^= 1;
        mram->eval();
        contextp->timeInc(1);
    }

    mram->final();

    // Coverage analysis (calling write only after the test is known to pass)
#if VM_COVERAGE
    Verilated::mkdir("logs");
    contextp->coveragep()->write("logs/coverage.dat");
#endif
}
