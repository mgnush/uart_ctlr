`begin_keywords "1800-2017"
/* verilator lint_off IMPORTSTAR */
import types_pkg::*;

module reset_sync 
(
  input logic clk,
  input logic rstN,
  output logic rstN_sync
);

  logic rstN_sync1;

  // Make reset deassert synchronously with metastability guard.
  always_ff @(posedge clk or negedge rstN) begin
    if (!rstN) begin
      rstN_sync <= rstN;
      rstN_sync1 <= rstN;
    end else begin
      rstN_sync1 <= rstN;
      rstN_sync <= rstN_sync1;
    end
  end

endmodule

`end_keywords
