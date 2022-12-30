// For std::unique_ptr
#include <memory>
#include <verilated.h>
#include "../obj_dir/Vtst_template.h"

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

    const std::unique_ptr<Vtst_template> slave{new Vtst_template{contextp.get(), "TEMPLATE"}};
    slave->clk_i = 1;

    slave->stb_i = 1;
    slave->we_i = 0;
    slave->adr_i = 0;
    slave->sel_i = 0;
    slave->dat_i = 0x11223344;
 
    //reset
    slave->rst_i = 0;
    slave->eval();
    slave->rst_i = 1;
    slave->eval();
    
    while (!contextp->gotFinish() && contextp->time() < 300)
    {
        if (contextp->time() == 2) slave->rst_i = 0; //read from #0
        if (contextp->time() == 4) slave->adr_i = 1; //read from #1
        if (contextp->time() == 6) slave->adr_i = 2; //read from #2
        if (contextp->time() == 8) slave->adr_i = 0, slave->we_i = 1, slave->sel_i = 0b1000; //write 0x11xxxxxx to #0
        if (contextp->time() == 10) slave->adr_i = 1, slave->sel_i = 0b0100; //write 0xxx22xxxx to #1
        if (contextp->time() == 12) slave->adr_i = 2, slave->sel_i = 0b0010; //write 0xxxxx33xx to #2
        if (contextp->time() == 14) slave->adr_i = 0, slave->we_i = 0; //read from #0
        if (contextp->time() == 16) slave->adr_i = 1; //read from #1
        if (contextp->time() == 18) slave->adr_i = 2; //read from #2

        slave->clk_i ^= 1;
        slave->eval();
        contextp->timeInc(1);  
    }

    slave->final();

    // Coverage analysis (calling write only after the test is known to pass)
#if VM_COVERAGE
    Verilated::mkdir("logs");
    contextp->coveragep()->write("logs/coverage.dat");
#endif
}