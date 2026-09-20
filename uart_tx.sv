`begin_keywords "1800-2017"
/* verilator lint_off IMPORTSTAR */
import types_pkg::*;

/* Data_valid is registered as send_data if received while
   ready is asserted. This means that from idle, it a 
   start condition is sent with a 2 cycle delay from data_valid.
*/

module uart_tx 
(
  input logic clk,
  input logic rstN,
  input logic [7:0] tx_data,
  input uart_parity_e parity_mode,
  input logic data_valid,
  input logic [15:0] baud_div,
  output logic busy,
  output logic ready,
  output logic tx
);

  typedef enum logic [2:0] {
    IDLE = 3'd0,
    START_BIT = 3'd1,
    DATA_BITS = 3'd2,
    PARITY_BIT = 3'd3,
    STOP_BIT = 3'd4
  } uart_tx_state_e;

  uart_tx_state_e state, next_state;
  logic [2:0] bit_count;
  logic [15:0] baud_counter;
  logic [7:0] data;
  logic send_data;

  always_comb begin
    case (state)
      IDLE: next_state = IDLE;
      START_BIT: next_state = DATA_BITS;
      DATA_BITS: begin
        if (bit_count == 3'd7) begin
          if (parity_mode == PARITY_NONE)
            next_state = STOP_BIT;
          else 
            next_state = PARITY_BIT;
        end else
          next_state = DATA_BITS;
      end
      PARITY_BIT: next_state = STOP_BIT;
      STOP_BIT: begin
        if (send_data)
          next_state = START_BIT;
        else
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end
  
  always_ff @(posedge clk or negedge rstN) begin
    if (!rstN) begin
      state <= IDLE;
      tx <= '1;
      bit_count <= '0;
      busy <= '0;
      ready <= '1;
      send_data <= '0;
    end else begin
      if (data_valid && ready) begin
        data <= tx_data;
        ready <= '0;
        send_data <= '1;
      end

      if (baud_counter == (baud_div - 1)) begin
        baud_counter <= '0;
        state <= next_state;
      end else 
        baud_counter <= baud_counter + 1;

      case (state)
        IDLE: begin
          busy <= '0;
          if (send_data) begin
            state <= START_BIT;
            baud_counter <= '0;
          end
        end

        START_BIT: begin
          send_data <= '0;
          busy <= '1;
          tx <= '0;
        end

        DATA_BITS: begin
          //todo: replace with data width variable?
          tx <= data[bit_count];
          if (baud_counter == (baud_div - 1)) begin  
            if (bit_count == 3'd7)
              bit_count <= '0;
            else
              bit_count <= bit_count + 1;
          end
        end

        PARITY_BIT: begin
          if (parity_mode == PARITY_ODD)
            tx <= ^data;
          else
            tx <= ~^data;
        end

        STOP_BIT: begin
          if (baud_counter == 0)
            ready <= '1;
          tx <= '1;
        end

        default: ;
      endcase
    end
  end

endmodule

`end_keywords
