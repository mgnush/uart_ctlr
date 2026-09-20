`begin_keywords "1800-2017"
/* verilator lint_off IMPORTSTAR */
import types_pkg::*;

module top (
  input logic clk,
  input logic rstN,
  input logic write,
  input logic read,
  input logic [31:0] addr,
  input logic [31:0] write_data, 
  output logic [31:0] read_data,
  output logic tx,
  input logic rx
);

uart_interface uart (.*); 

endmodule

`end_keywords
