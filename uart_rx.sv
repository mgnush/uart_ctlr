`begin_keywords "1800-2017"
/* verilator lint_off IMPORTSTAR */
import types_pkg::*;

module uart_rx 
(
  input logic clk,
  input logic rstN,
  input uart_parity_e parity_mode,
  input logic rx,
  input logic [15:0] baud_div,
  output logic [7:0] rx_data,
  output logic parity_fault,
  output logic stop_fault,
  output logic data_ready, // High for one clk cycle when data is registered
  output logic busy
);

  typedef enum logic [2:0] {
    IDLE,
    START_BIT,
    DATA_BITS,
    PARITY_BIT,
    STOP_BIT
  } uart_rx_state_e;

  uart_rx_state_e state, next_state;
  logic [2:0] bit_count;
  logic [15:0] baud_counter;
  logic [7:0] data;

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
      STOP_BIT: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end
  
  always_ff @(posedge clk or negedge rstN) begin
    if (!rstN) begin
      state <= IDLE;
      bit_count <= '0;
      busy <= '0;
      parity_fault <= '0;
      stop_fault <= '0;
      data_ready <= '0;
    end else begin
      data_ready <= '0;
      if (baud_counter == (baud_div - 1)) begin
        baud_counter <= '0;
        state <= next_state;
      end else 
        baud_counter <= baud_counter + 1;

      case (state)
        IDLE: begin
          busy <= '0;
          if (rx == 0) begin
            state <= START_BIT;
            baud_counter <= '0;
          end
        end

        START_BIT: begin
          busy <= '1;
          // Glitch detection
          if (baud_counter <= (baud_div / 2)) begin
            if (rx == 1)
              state <= IDLE;
          end
        end

        DATA_BITS: begin
          //todo: replace with data width parameter?
          if (baud_counter == (baud_div / 2)) begin
            data[bit_count] <= rx;
          end
          if (baud_counter == (baud_div - 1)) begin
            if (bit_count == 3'd7)
              bit_count <= '0;
            else
              bit_count <= bit_count + 1;
          end
        end

        PARITY_BIT: begin
          if (baud_counter == (baud_div / 2)) begin
            if (parity_mode == PARITY_ODD) begin
              if (^data == rx)
                parity_fault <= '0;
              else
                parity_fault <= '1;
            end else begin
              if (~^data == rx)
                parity_fault <= '0;
              else
                parity_fault <= '1;
            end
          end          
        end

        STOP_BIT: begin
          if (baud_counter == 0) begin
            rx_data <= data;
            data_ready <= '1;
          end
          if (baud_counter == (baud_div / 2)) begin
            if (rx == 0)
              stop_fault <= '1;
            else
              stop_fault <= '0;
          end
          if (baud_counter > (baud_div / 2)) begin
            if (rx == 0) begin
              state <= START_BIT;
              baud_counter <= '0;
            end
          end
        end

        default: ;
      endcase
    end
  end

endmodule

`end_keywords
