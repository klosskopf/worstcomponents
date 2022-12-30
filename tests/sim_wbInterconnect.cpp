// For std::unique_ptr
#include <memory>
#include <verilated.h>
#include "../obj_dir/Vtst_wbInterconnect.h"

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

    const std::unique_ptr<Vtst_wbInterconnect> interconnect{new Vtst_wbInterconnect{contextp.get(), "Wishbone Interconnect"}};
    interconnect->clk_i = 0;
    interconnect->mcyc_i[0] = 0;
    interconnect->mcyc_i[1] = 0;
    interconnect->madr_i[0] = 1;
    interconnect->madr_i[1] = 0x40000000;
    interconnect->mwe_i[0] = 1;
    interconnect->mwe_i[1] = 0;

    while (!contextp->gotFinish() && contextp->time() < 34)
    {
        if (contextp->time() == 4) interconnect->mcyc_i[1] = 1; //Master 1 wants access and should get it
        if (contextp->time() == 8) interconnect->mcyc_i[0] = 1; //Master 0 wants access and has to wait for MAster 1 to finish
        if (contextp->time() == 12) interconnect->mcyc_i[1] = 0;//Master 1 finishes and access is transfered to master 0
        if (contextp->time() == 16) interconnect->mcyc_i[0] = 0;//Master 0 finishes and no master has access
        if (contextp->time() == 20)                             //Both masters want access and master0 gets it
        {
            interconnect->mcyc_i[0] = 1;
            interconnect->mcyc_i[1] = 1;
        }
        if (contextp->time() == 24) interconnect->mcyc_i[0] = 0;//master 0 is done and master 1 gets access
        if (contextp->time() == 28) interconnect->mcyc_i[1] = 0;//master 1 is done and no master has access

        interconnect->eval();
        contextp->timeInc(1);  
        interconnect->clk_i ^= 1;
    }

    interconnect->final();

    // Coverage analysis (calling write only after the test is known to pass)
#if VM_COVERAGE
    Verilated::mkdir("logs");
    contextp->coveragep()->write("logs/coverage.dat");
#endif
}
