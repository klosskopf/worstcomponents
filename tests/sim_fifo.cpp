// For std::unique_ptr
#include <memory>
#include <verilated.h>
#include "../obj_dir/Vtst_fifo.h"

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

    const std::unique_ptr<Vtst_fifo> fifo{new Vtst_fifo{contextp.get(), "FIFO"}};
    fifo->clk_i = 1;
    fifo->setData_i = 0;
    fifo->getData_i = 0;
 
    //reset
    fifo->rst_i = 0;
    fifo->eval();
    fifo->rst_i = 1;
    fifo->eval();
    
    while (!contextp->gotFinish() && contextp->time() < 50)
    {
        if (contextp->time() == 2)
        {
            fifo->rst_i = 0;
        }
        if (contextp->time() == 4)
        {
            fifo->data_i = 0x1;
            fifo->setData_i = 1;
        }
        if (contextp->time() == 6)
        {
            fifo->data_i = 0x2;
        }
        if (contextp->time() == 8)
        {
            fifo->data_i = 0x3;
        }
        if (contextp->time() == 10)
        {
            fifo->data_i = 0x4;
        }
        if (contextp->time() == 12)
        {
            fifo->data_i = 0x5;
        }
        if (contextp->time() == 14)
        {
            fifo->data_i = 0x6;
        }
        if (contextp->time() == 16)
        {
            fifo->data_i = 0x7;
        }
        if (contextp->time() == 18)
        {
            fifo->data_i = 0x8;
        }
        if (contextp->time() == 20)
        {
            fifo->data_i = 0;
            fifo->setData_i = 0;
        }
        if (contextp->time() == 24)
        {
            fifo->getData_i = 1;
        }

        fifo->clk_i ^= 1;
        fifo->eval();
        contextp->timeInc(1);  
    }

    fifo->final();

    // Coverage analysis (calling write only after the test is known to pass)
#if VM_COVERAGE
    Verilated::mkdir("logs");
    contextp->coveragep()->write("logs/coverage.dat");
#endif
}
