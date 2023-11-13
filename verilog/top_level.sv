/* [top_level.sv]
 * - This takes in a 32 bit int value called floating_point and a clock, which will
 * then be put into the fp_convertor module. The output will be a 7-segment display
 * with a width equal to the DISPLAY_WIDTH variable.
 *
 * @author Triston Babers
 * @contact Triston.Babers.Official@gmail.com
 */
module top_level #(parameter DISPLAY_WIDTH = 8) (
  input                         [31:0] floating_point,
  input                                clk, reset,
  output wire [DISPLAY_WIDTH-1:0][6:0] seven_segment_array
  );

  // Registers
  logic [DISPLAY_WIDTH-1:0][3:0] BCD;

  fp_convertor #(.DISPLAY_WIDTH(DISPLAY_WIDTH)) fp_convertor(
    .floating_point(floating_point), .BCD(BCD), .clk(clk), .reset(reset)
  );

  // Generate BCD to 7-Segment Decoders
  genvar i;
  generate
    for (i = 0; i < DISPLAY_WIDTH; i = i + 1) begin : generate_bcd_to_7segment
      bcd_to_7segment bcd_to_7segment(
        .clk(clk),
        .bcd(BCD[i]),
        .seven_segment(seven_segment_array[i])
      );
    end : generate_bcd_to_7segment
  endgenerate
endmodule