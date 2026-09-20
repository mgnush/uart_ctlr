VERILATOR := verilator

VFLAGS := -Wall \
          --trace-vcd \
          -CFLAGS -DVL_TIME_CONTEXT

# Generated dirs
TX_DIR   := obj_dir_tx
RX_DIR   := obj_dir_rx
FIFO_DIR := obj_dir_fifo
UART_DIR := obj_dir_uart

.PHONY: tx
tx:	
	$(VERILATOR) $(VFLAGS) \
		--cc types_pkg.sv uart_tx.sv \
		--top-module uart_tx \
		--exe tx_test.cpp \
		--Mdir $(TX_DIR) \
		--build
	./$(TX_DIR)/Vuart_tx

.PHONY: rx
rx: 
	$(VERILATOR) $(VFLAGS) \
		--cc types_pkg.sv uart_rx.sv \
		--top-module uart_rx \
		--exe rx_test.cpp \
		--Mdir $(RX_DIR) \
		--build
	./$(RX_DIR)/Vuart_rx

.PHONY: fifo
fifo: 
	$(VERILATOR) $(VFLAGS) \
		--cc types_pkg.sv fifo.sv \
		--top-module fifo \
		--exe fifo_test.cpp \
		--Mdir $(FIFO_DIR) \
		--build
	./$(FIFO_DIR)/Vfifo

.PHONY: uart
uart: 
	$(VERILATOR) $(VFLAGS) \
		--cc types_pkg.sv fifo.sv uart_tx.sv uart_rx.sv uart_interface.sv \
		--top-module uart_interface \
		--exe uart_interface_test.cpp \
		--Mdir $(UART_DIR) \
		--build
	./$(UART_DIR)/Vuart_interface

.PHONY: all
all: tx rx fifo uart

.PHONY: clean
clean:
	rm -rf $(TX_DIR) $(RX_DIR) $(FIFO_DIR) $(UART_DIR)
	rm -f *.vcd