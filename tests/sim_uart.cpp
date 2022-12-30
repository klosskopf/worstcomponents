// For std::unique_ptr
#include <memory>
#include <verilated.h>
#include "../obj_dir/Vtst_uart.h"

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

    const std::unique_ptr<Vtst_uart> uart{new Vtst_uart{contextp.get(), "UART"}};
    uart->clk_i = 1;
    uart->adr_i = 0;
    uart->dat_i = 0x12;
    uart->stb_i = 0;
    uart->sel_i = 0b0001;
    uart->we_i = 1;
    uart->uartRx_i = 0;
 
    //reset
    uart->rst_i = 0;
    uart->eval();
    uart->rst_i = 1;
    uart->eval();
    
    while (!contextp->gotFinish() && contextp->time() < 300)
    {
        if (contextp->time() == 2)
        {
            uart->rst_i = 0;
        }
        if (contextp->time() == 4)
        {
            uart->stb_i = 1;
        }
        if (contextp->time() == 6)
        {
            uart->dat_i = 0x34000000;
        }
        if (contextp->time() == 8)
        {
            uart->stb_i = 0;
        }
        if (contextp->time() == 250)
        {
            uart->we_i = 0;
            uart->stb_i = 1;
        }

        uart->uartRx_i = uart->uartTx_o;

        uart->clk_i ^= 1;
        uart->eval();
        contextp->timeInc(1);  
    }

    uart->final();

    // Coverage analysis (calling write only after the test is known to pass)
#if VM_COVERAGE
    Verilated::mkdir("logs");
    contextp->coveragep()->write("logs/coverage.dat");
#endif
}
