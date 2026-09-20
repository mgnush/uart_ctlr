# UART
Configurable UART peripheral written in SystemVerilog with Verilator tests.

Transmit and receive functionaliy with FIFOs, with a simple 32bit memory-mapped front-end interface.
The memory is word-aligned to make cpu integration easier later.

## Architecture
The UART consists of the following modules:  
`uart_interface`: Memory-mapped register interface and top-level UART control  
`uart_tx`: UART transmitter  
`uart_rx`: UART receiver  
`fifo`: 8-byte circular FIFO, instantiated separately for TX and RX  
```
      (top)
        │
  uart_interface
   |           |  
tx fifo     rx fifo
   │           |
uart_tx     uart_rx
   |           │
  tx           rx
```

## Interface
<div style="white-space: pre-wrap;">
`clk`       | Input  1  | System clock  
`rstN`      | Input  1  | Active-low asynchronous reset  
`write`     | Input  1  | Register write request  
`read`      | Input  1  | Register read request  
`addr`      | Input  32 | Byte address  
`write_data`| Input  32 | Register write data  
`read_data` | Output 32 | Register read data   
`tx`        | Output 1  | UART serial transmit  
`rx`        | Input  1  | UART serial receive  
</div>
`read` and `write` are mutually exclusive.

## Register Map
<div style="white-space: pre-wrap;">
`0x00` | `TX_DATA` | W  | Write a byte to the TX FIFO  
`0x04` | `RX_DATA` | R  | Read the oldest byte from the RX FIFO  
`0x08` | `STATUS`  | R  | UART and FIFO status  
`0x0C` | `CTRL`    | RW | UART configuration  
</div>

Only the lower 8 bits of `TX_DATA` and `RX_DATA` contain UART data.  

### STATUS (0x08)
<div style="white-space: pre-wrap;">
0     | `TX_BUSY`         | Transmitter is currently active  
1     | `RX_BUSY`         | Receiver is currently active  
2     | `RX_STOP_FAULT`   | Stop-bit error detected  
3     | `RX_PARITY_FAULT` | Parity error detected  
4     | `TX_FULL`         | TX FIFO is full  
5     | `TX_EMPTY`        | TX FIFO is empty  
6     | `RX_FULL`         | RX FIFO is full  
7     | `RX_EMPTY`        | RX FIFO is empty  
8     | `RX_OVERFLOW`     | RX FIFO overflow has occurred  
9     | `TX_OVERFLOW`     | Write attempted while TX FIFO was full  
31:10 | -                 | Reserved  
</div>
 
`RX_OVERFLOW` and `TX_OVERFLOW` are sticky flags, cleared when `STATUS` is read.  

### CTRL (0x0C)
<div style="white-space: pre-wrap;">
1:0   | `PARITY_MODE` | UART parity configuration (0 = None, 1 = Odd, 2 = Even)  
15:2  | -             | Reserved    
31:16 | `BAUD_DIV`    | Baud-rate clock divider   
</div>

## FIFO Behaviour
Both TX and RX use 8-byte circular FIFOs.
The FIFOs continuously present the oldest entry. A read advances the read pointer.

Writing to a full FIFO overwrites its oldest entry. The UART interface prevents
this behaviour for the TX FIFO and instead sets `TX_OVERFLOW`.

The RX FIFO intentionally permits overwrite-on-full because incoming UART data
cannot be stalled. When this occurs, `RX_OVERFLOW` is set to indicate that
unread receive data has been lost.

Reading an empty FIFO is not internally prevented. Parent modules are responsible
for checking `empty` before asserting `read`.

## Transmit Operation
Software transmits a byte by writing it to `TX_DATA`.

The byte is placed into the TX FIFO. The transmitter automatically consumes
bytes from the FIFO whenever it is ready.

If software attempts to write while the TX FIFO is full, the byte is rejected
and `TX_OVERFLOW` is set.

## Receive Operation
Received UART bytes are automatically written into the RX FIFO.

Software can check `RX_EMPTY` and read the oldest available byte through
`RX_DATA`.

If a new byte arrives while the RX FIFO is full, the oldest unread byte is
overwritten and `RX_OVERFLOW` is set.

## Verification/Sim
The individual modules are simulated using Verilator.

```bash
make tx
make rx
make fifo
make uart
```