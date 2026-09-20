`begin_keywords "1800-2017"
/* verilator lint_off IMPORTSTAR */
import types_pkg::*;
//Make depth a parameter
/* Implement as memory-like registers / circular fifo
   which should scale better at higher depths.
*/
module fifo (
  input logic clk,
  input logic rstN,
  input logic write,
  input logic read,
  input logic [7:0] data_in, 
  output logic [7:0] data_out,
  output logic empty, // There is no handling to prevent fifo corruption if read when empty
  output logic full // Writing when full will overwrite oldest member 
);

  logic [7:0] data [7:0];
  logic [2:0] write_i, read_i;
  logic [3:0] full_counter;

  function automatic logic [2:0] index_incr(input logic [2:0] in);
    if (in == 7)
      index_incr = '0;
    else
      index_incr = in + 1;
  endfunction: index_incr

  always_comb begin
    empty = (full_counter == 0);
    full = (full_counter == 8);
    data_out = data[read_i];
  end

  always_ff @(posedge clk or negedge rstN) begin
    if (!rstN) begin
      data <= '{default:'0};
      write_i <= '0;
      read_i <= '0;
      full_counter <= '0;
    end else begin
      case ({write, read})
        2'b10: begin
          data[write_i] <= data_in;
          write_i <= index_incr(write_i);
          if (full_counter < 8)
            full_counter <= full_counter + 1;
          else
            read_i <= index_incr(read_i);
        end
        2'b01: begin
          read_i <= index_incr(read_i);
          full_counter <= full_counter - 1;
        end
        2'b11: begin
          data[write_i] <= data_in;
          write_i <= index_incr(write_i);
          read_i <= index_incr(read_i);
        end
        default: ;
      endcase
    end

  end

endmodule

`end_keywords
