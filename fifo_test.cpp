#include <memory>
#include <cstdio>

#include "Vfifo.h" 
#include "verilated.h"
#include "verilated_vcd_c.h"

void clock_cycle(Vfifo& top, VerilatedContext& context, VerilatedVcdC &trace) {
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

  auto top = std::make_unique<Vfifo>(context.get());

  // Enable waveform tracing
  context->traceEverOn(true);

  auto trace = std::make_unique<VerilatedVcdC>();

  // 5 levels  (overkill)
  top->trace(trace.get(), 5);

  trace->open("uart_fifo.vcd");

  top->clk        = 0;
  top->rstN       = 0;
  top->write      = 0;
  top->read       = 0;
  top->data_in    = 0xff;

  // Run reset for a few clock cycles
  for (int i = 0; i < 5; i++) {
    clock_cycle(*top, *context, *trace);
  }
  top->rstN = 1;
  clock_cycle(*top, *context, *trace);

  // Write 2 bytes consecutively
  top->write = 1;
  clock_cycle(*top, *context, *trace);
  top->data_in += 5;
  clock_cycle(*top, *context, *trace);
  top->write = 0;
  clock_cycle(*top, *context, *trace);

  // Write byte after write reset
  top->data_in += 5;
  top->write = 1;
  clock_cycle(*top, *context, *trace);
  top->write = 0;
  clock_cycle(*top, *context, *trace);

  // Read 2 bytes consecutively
  top->read = 1;
  clock_cycle(*top, *context, *trace);
  clock_cycle(*top, *context, *trace);
  top->read = 0;
  clock_cycle(*top, *context, *trace);

  // Write and read on same edge
  top->data_in += 5;
  top->write = 1;
  top->read = 1;
  clock_cycle(*top, *context, *trace);
  top->write = 0;
  top->read = 0;
  clock_cycle(*top, *context, *trace);

  // Empty fifo 
  top->read = 1;
  clock_cycle(*top, *context, *trace);
  top->read = 0;

  // Fill fifo
  for (int i = 0; i < 8; i++) {
    top->data_in += 5;
    top->write = 1;
    clock_cycle(*top, *context, *trace);
  }
  top->write = 0;
  clock_cycle(*top, *context, *trace);

  trace->close();
  top->final();
  return 0;
}