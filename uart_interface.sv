`begin_keywords "1800-2017"
/* verilator lint_off IMPORTSTAR */
import types_pkg::*;

module uart_interface (
  input logic clk,
  input logic rstN,
  input logic write,
  input logic read,
  /* verilator lint_off UNUSEDSIGNAL */
  input logic [31:0] addr,
  /* verilator lint_on UNUSEDSIGNAL */
  input logic [31:0] write_data, 
  output logic [31:0] read_data,
  output logic tx,
  input logic rx
);

typedef enum logic [3:0] {
  TX_DATA = 4'h0,
  RX_DATA = 4'h4,
  STATUS = 4'h8,
  CTRL = 4'hC
} uart_reg_map;

logic [31:0] status, ctrl;
logic [15:0] baud_div;
logic [1:0] parity_mode;
// uart_tx 
logic tx_data_valid, tx_busy, tx_ready;
// uart_rx
logic rx_parity_fault, rx_stop_fault, rx_data_ready, rx_busy;
// tx fifo
logic [7:0] tx_fifo_in, tx_fifo_out;
logic tx_fifo_write, tx_fifo_read;
logic tx_empty, tx_full;
// rx fifo
logic [7:0] rx_fifo_in, rx_fifo_out;
logic rx_fifo_read;
logic rx_empty, rx_full;
logic tx_overflow; // Sticky flag to indicate tx fifo was attempted written while full, no overwrite
logic rx_overflow; // Sticky flag to indicate that oldest rx fifo member was overwritten since last status read

logic tx_fifo_state;

uart_tx uart_tx (.busy(tx_busy), .tx_data(tx_fifo_out), .ready(tx_ready), .data_valid(tx_data_valid), .*);
uart_rx uart_rx (.busy(rx_busy), .rx_data(rx_fifo_in), .parity_fault(rx_parity_fault), .stop_fault(rx_stop_fault), .data_ready(rx_data_ready), .*);
fifo fifo_tx (.write(tx_fifo_write), .read(tx_fifo_read), .data_in(tx_fifo_in), .data_out(tx_fifo_out), .empty(tx_empty), .full(tx_full), .*);
fifo fifo_rx (.write(rx_data_ready), .read(rx_fifo_read), .data_in(rx_fifo_in), .data_out(rx_fifo_out), .empty(rx_empty), .full(rx_full), .*);

// Don't register tx fifo writes to reduce latency and avoid timing issues on single-cycle writes
assign tx_fifo_write = write && !tx_full && (addr[3:0] == TX_DATA);
assign tx_fifo_in = write_data[7:0];

always_comb begin
  parity_mode = ctrl[1:0];
  baud_div = ctrl[31:16];

  status[0] = tx_busy;
  status[3:1] = {rx_parity_fault, rx_stop_fault, rx_busy};
  status[5:4] = {tx_empty, tx_full};
  status[7:6] = {rx_empty, rx_full};
  status[8] = rx_overflow; // Cleared on reads
  status[9] = tx_overflow; // Cleared on reads
  status[31:10] = '0;
end

always_ff @(posedge clk or negedge rstN) begin
  if (!rstN) begin
    ctrl <= 32'h000A0000;
    tx_data_valid <= '0;
    tx_fifo_state <= 0;
    tx_fifo_read <= '0;
    rx_fifo_read <= 0;
    tx_overflow <= '0;
    rx_overflow <= '0;
    read_data <= '0;
  end else begin
    rx_fifo_read <= '0;
    
    if (write) begin
      case (addr[3:0])
        TX_DATA: begin
          if (tx_full)
            tx_overflow <= '1;
        end
        CTRL: ctrl <= write_data;
        default: ;
      endcase
    end else if (read) begin
      case (addr[3:0])
        RX_DATA: begin
          if (!rx_empty) begin
            read_data <= {24'b0, rx_fifo_out};
            rx_fifo_read <= '1;
          end
        end
        STATUS: begin
          read_data <= status;
          rx_overflow <= '0;
          tx_overflow <= '0;
        end
        CTRL: read_data <= ctrl;
        default: read_data <= '0;
      endcase
    end

    // Keep sending tx when fifo isn't empty
    case (tx_fifo_state)
      0: begin
        tx_fifo_read <= '0;
        if (!tx_empty && tx_ready) begin
          tx_data_valid <= '1;
          tx_fifo_state <=  1;
        end
      end
      1: begin
        tx_data_valid <= '0;
        tx_fifo_read <=  '1;
        tx_fifo_state <= '0;
      end
      default: ;
    endcase

    if (rx_data_ready && rx_full)
      rx_overflow <= '1;
  end
end
  
endmodule

`end_keywords
