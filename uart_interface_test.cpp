#include <memory>
#include <cstdio>
#include <stdexcept>
#include <string>
#include <iostream>
#include <random>

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

void check(bool condition, const std::string& message)
{
    if (condition) {
      std::cout << message << ": OK\n";
    } else {
      //throw std::runtime_error(message + ": FAIL\n");
      std::cout << message << ": FAIL\n";
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
  // Wait for release reset
  top->rstN = 1;
  for (int i = 0; i < 5; i++) {
    clock_cycle(*top, *context, *trace);
  }

  // Configure baud div
  uint32_t ctrl_data = (0x4 << 16);
  top->write_data = ctrl_data;
  top->addr = 0xC;
  top->write = 1;
  clock_cycle(*top, *context, *trace);
  top->write = 0;
  clock_cycle(*top, *context, *trace);
  // Read back control reg
  top->read = 1;
  clock_cycle(*top, *context, *trace);
  check(top->read_data == ctrl_data, "Ctrl readback");
  top->read = 0;
  clock_cycle(*top, *context, *trace);

  // Write 10 bytes to tx fifo consecutively
  uint8_t write_data[10];
  std::mt19937 rng(12345);
  std::uniform_int_distribution<int> dist(0, 255);
  for (int i = 0; i < 10; i++) {
    write_data[i] = dist(rng);
    top->write_data = write_data[i];
    top->addr = 0;
    top->write = 1;
    clock_cycle(*top, *context, *trace);
  }
  // Fifo should have been filled before the last write, check that tx_overflow is set correctly
  top->addr = 0x8;
  top->read = 1;
  top->write = 0;
  clock_cycle(*top, *context, *trace);
  bool tx_ovf = ((top->read_data >> 9) & 0x1);
  check(tx_ovf, "TX Overflow set");
  // Check that ovf flg is cleared as expected
  clock_cycle(*top, *context, *trace);
  tx_ovf = ((top->read_data >> 9) & 0x1);
  check(!tx_ovf, "TX Overflow cleared");
  top->read = 0;
  clock_cycle(*top, *context, *trace);

  // Receive 10 bytes on rx
  uint8_t read_data[8];
  uint8_t ix;
  for (int i = 0; i < 10; i++) {
    ix = i % 8;
    read_data[ix] = dist(rng);
    top->rx = 0;
    baud_cycle(*top, *context, *trace);
    for (int i = 0; i < 8; i++) {
      top->rx = (read_data[ix] >> i) & 0x1;
      baud_cycle(*top, *context, *trace);
    }
    top->rx = 1;
    baud_cycle(*top, *context, *trace);
  }
  // Fifo should have been filled before the last read, check that rx_overflow is set correctly
  top->addr = 0x8;
  top->read = 1;
  clock_cycle(*top, *context, *trace);
  bool rx_ovf = ((top->read_data >> 8) & 0x1);
  check(rx_ovf, "RX Overflow set");
  // Check that ovf flg is cleared as expected
  clock_cycle(*top, *context, *trace);
  rx_ovf = ((top->read_data >> 8) & 0x1);
  check(!rx_ovf, "RX Overflow cleared");
  top->read = 0;
  clock_cycle(*top, *context, *trace);

  // Read until rx fifo is empty
  uint8_t rx_data;
  bool rx_empty = false;
  while (!rx_empty) {
    ix = (ix + 1) % 8;
    top->addr = 0x4;
    top->read = 1;
    clock_cycle(*top, *context, *trace);
    check(top->read_data == read_data[ix], "Read");
    top->addr = 0x8;
    clock_cycle(*top, *context, *trace);
    rx_empty = ((top->read_data >> 7) & 0x1);
  }

  trace->close();
  top->final();
  return 0;
}