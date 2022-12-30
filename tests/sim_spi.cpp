// For std::unique_ptr
#include <memory>
#include <verilated.h>
#include "../obj_dir/Vtst_spi.h"

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

    const std::unique_ptr<Vtst_spi> spi{new Vtst_spi{contextp.get(), "SPI"}};
    spi->clk_i = 1;
    spi->adr_i = 0;
    spi->sel_i = 0b1111;
    spi->dat_i = 0x12;
    spi->spiMiso_i = 1;
    spi->stb_i = 0;
    spi->we_i = 1;
 
    //reset
    spi->rst_i = 0;
    spi->eval();
    spi->rst_i = 1;
    spi->eval();
    
    while (!contextp->gotFinish() && contextp->time() < 2000)
    {
        if (contextp->time() == 2)
        {
            spi->rst_i = 0;
        }
        if (contextp->time() == 4)
        {
            spi->stb_i = 1;
        }
        if (contextp->time() == 6)
        {
            spi->dat_i = 0x00000034;
        }
        if (contextp->time() == 8)
        {
            spi->stb_i = 0;
        }
        if (contextp->time() == 69)
        {
            spi->spiMiso_i = 0;
        }

        spi->clk_i ^= 1;
        spi->eval();
        contextp->timeInc(1);  
    }

    spi->final();

    // Coverage analysis (calling write only after the test is known to pass)
#if VM_COVERAGE
    Verilated::mkdir("logs");
    contextp->coveragep()->write("logs/coverage.dat");
#endif
}
