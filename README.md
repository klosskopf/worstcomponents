# Components
The SoCs consist of different memory and peripheral cores connected with a wishbone interconnect. These are placed here and included in the SoCs.
Every Core has a verilator simulation, but these are very minimalistic and by no means complete or satisfactory.

- rom: a synchronous read ROM (uses blockram)
- ram: a synchronous read/write RAM (uses blockram)
- parallelport: a simple 32bit input and a 32bit output port. no tristate, or other fancypants
- spi: a 8bit mode 1 SPI master interface with variable clock and 8byte fifo
- uart: a uart interface with 8byte fifo
- mram: memory map a spi mram or flash. With variable address length
- template: A template to ease development of new peripherals with n registers

## Test
To run the Tests, use the single Makefile in the top dir. The single tests are called with ```make test_<modulename>```
