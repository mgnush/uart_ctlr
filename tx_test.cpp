#include <memory>
#include <cstdio>

#include "Vuart_tx.h" 
#include "verilated.h"
#include "verilated_vcd_c.h"

void clock_cycle(Vuart_tx& top, VerilatedContext& context, VerilatedVcdC &trace) {
  top.clk = 0;
  top.eval();
  trace.dump(context.time());
  context.timeInc(1);

  top.clk = 1;
  top.eval();
  trace.dump(context.time());
  context.timeInc(1);
}

int main(int argc, char** argv) {
  auto context = std::make_unique<VerilatedContext>();
  context->commandArgs(argc, argv);

  auto top = std::make_unique<Vuart_tx>(context.get());

  // Enable waveform tracing
  context->traceEverOn(true);

  auto trace = std::make_unique<VerilatedVcdC>();

  // Trace the DUT
  top->trace(trace.get(), 5);

  // Output file
  trace->open("uart_tx.vcd");

  // Initial input values
  top->clk        = 0;
  top->rstN       = 0;
  top->tx_data    = 0;
  top->data_valid = 0;
  top->parity_mode = 0;
  top->baud_div = 10;

  // Run reset for a few clock cycles
  for (int i = 0; i < 5; i++) {
    clock_cycle(*top, *context, *trace);
  }
  top->rstN = 1;
  clock_cycle(*top, *context, *trace);

  top->tx_data = 0x53;
  top->data_valid = 1;
  clock_cycle(*top, *context, *trace);
  top->data_valid = 0;
  while (!top->ready) {
    clock_cycle(*top, *context, *trace);
  }

  top->tx_data = 0x21;
  top->data_valid = 1;
  clock_cycle(*top, *context, *trace);
  top->data_valid = 0;
  
  for (int i = 0; i < 200; i++) {
    clock_cycle(*top, *context, *trace);
  }

  trace->close();
  top->final();
  return 0;
}