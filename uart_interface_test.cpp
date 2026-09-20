#include <memory>
#include <cstdio>

#include "Vuart_interface.h" 
#include "verilated.h"
#include "verilated_vcd_c.h"

void clock_cycle(Vuart_interface& top, VerilatedContext& context, VerilatedVcdC &trace) {
  top.clk = 0;
  top.eval();
  trace.dump(context.time());
  context.timeInc(1);

  top.clk = 1;
  top.eval();
  trace.dump(context.time());
  context.timeInc(1);
}

void baud_cycle(Vuart_interface& top, VerilatedContext& context, VerilatedVcdC &trace) {
  for (int i = 0; i < 4; i++) {
    clock_cycle(top, context, trace);
  }
}

int main(int argc, char** argv) {
  auto context = std::make_unique<VerilatedContext>();
  context->commandArgs(argc, argv);

  auto top = std::make_unique<Vuart_interface>(context.get());

  // Enable waveform tracing
  context->traceEverOn(true);

  auto trace = std::make_unique<VerilatedVcdC>();

  top->trace(trace.get(), 5);

  trace->open("uart_interface.vcd");

  top->clk        = 0;
  top->rstN       = 0;
  top->write      = 0;
  top->read       = 0;
  top->addr       = 0;
  top->write_data = 0;
  top->rx  =  1;

  // Run reset for a few clock cycles
  for (int i = 0; i < 5; i++) {
    clock_cycle(*top, *context, *trace);
  }
  top->rstN = 1;
  clock_cycle(*top, *context, *trace);

  // Configure baud div
  top->write_data = (0x4 << 16);
  top->addr = 0xC;
  top->write = 1;
  clock_cycle(*top, *context, *trace);
  top->write = 0;
  clock_cycle(*top, *context, *trace);

  // Write 10 bytes to tx fifo
  for (int i = 0; i < 10; i++) {
    top->write_data += 5;
    top->addr = 0;
    top->write = 1;
    clock_cycle(*top, *context, *trace);
  }
  top->write = 0;
  clock_cycle(*top, *context, *trace);

  // Receive 10 bytes on rx
  uint8_t rx = 0x01;
  for (int i = 0; i < 10; i++) {
    top->rx = 0;
    baud_cycle(*top, *context, *trace);
    for (int i = 0; i < 8; i++) {
      top->rx = (rx >> i) & 0x1;
      baud_cycle(*top, *context, *trace);
    }
    top->rx = 1;
    baud_cycle(*top, *context, *trace);
    rx += 5;
  }

  // Read until rx fifo is empty
  uint8_t rx_data;
  bool rx_empty = false;
  while (!rx_empty) {
    top->addr = 0x4;
    top->read = 1;
    clock_cycle(*top, *context, *trace);
    rx_data = top->read_data;
    top->addr = 0x8;
    clock_cycle(*top, *context, *trace);
    rx_empty = ((top->read_data >> 7) & 0x1);
    printf("Read %d\n", rx_data);
  }
  top->read = 0;
  clock_cycle(*top, *context, *trace);

  trace->close();
  top->final();
  return 0;
}