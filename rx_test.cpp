#include <memory>
#include <cstdio>

#include "Vuart_rx.h" 
#include "verilated.h"
#include "verilated_vcd_c.h"

void clock_cycle(Vuart_rx& top, VerilatedContext& context, VerilatedVcdC &trace) {
  top.clk = 0;
  top.eval();
  trace.dump(context.time());
  context.timeInc(1);

  top.clk = 1;
  top.eval();
  trace.dump(context.time());
  context.timeInc(1);
}

void baud_cycle(Vuart_rx& top, VerilatedContext& context, VerilatedVcdC &trace) {
  for (int i = 0; i < 4; i++) {
    clock_cycle(top, context, trace);
  }
}

int main(int argc, char** argv) {
  auto context = std::make_unique<VerilatedContext>();
  context->commandArgs(argc, argv);

  auto top = std::make_unique<Vuart_rx>(context.get());

  // Enable waveform tracing
  context->traceEverOn(true);

  auto trace = std::make_unique<VerilatedVcdC>();

  // 5 levels  (overkill)
  top->trace(trace.get(), 5);

  trace->open("uart_rx.vcd");

  top->clk        = 0;
  top->rstN       = 0;
  top->parity_mode = 0;
  top->baud_div   = 4;
  top->rx         = 1;

  // Run reset for a few clock cycles
  for (int i = 0; i < 5; i++) {
    clock_cycle(*top, *context, *trace);
  }
  top->rstN = 1;
  clock_cycle(*top, *context, *trace);

  uint8_t rx = 0xb4;
  top->rx = 0;
  baud_cycle(*top, *context, *trace);
  for (int i = 0; i < 8; i++) {
    top->rx = (rx >> i) & 0x1;
    baud_cycle(*top, *context, *trace);
  }
  top->rx =  1;
  baud_cycle(*top, *context, *trace);

  rx =  0x35;
  top->rx = 0;
  baud_cycle(*top, *context, *trace);
  for (int i = 0; i < 8; i++) {
    top->rx = (rx >> i) & 0x1;
    baud_cycle(*top, *context, *trace);
  }
  top->rx =  1;
  baud_cycle(*top, *context, *trace);
  for (int i = 0; i < 20; i++) {
    clock_cycle(*top, *context, *trace);
  }

  trace->close();
  top->final();
  return 0;
}