/* [bcd_to_7semgment]
 * - This takes a 4-bit BCD value and converts it to a 7-bit 7-segment
 * display pattern for the correct symbol.
 *   
 * Display Value|  BCD
 * -------------+--------------
 *         0-9  | 0000-1001
 *          e   | 1010
 *          .   | 1011
 *          F   | 1100
 *          -   | 1101
 *          N   | 1110
 *          A   | 1111
 *
 * @author Triston Babers
 * @contact Triston.Babers.Official@gmail.com
 */
module bcd_to_7segment (
  input        [3:0] bcd,
  input              clk,
  output logic [6:0] seven_segment
  );
 
  /*_________[ 7-Segment Pattern ]__________
   *  7'b A B C D E F G    
   *           ___A__
   *        F /     / B
   *         /__G__/
   *      E /     / C
   *       /__D__/
   */
  always_comb begin
    case (bcd)
      4'b0000 : seven_segment = 7'b1111110;
      4'b0001 : seven_segment = 7'b0110000;
      4'b0010 : seven_segment = 7'b1101101;
      4'b0011 : seven_segment = 7'b1111001;
      4'b0100 : seven_segment = 7'b0110011;          
      4'b0101 : seven_segment = 7'b1011011;
      4'b0110 : seven_segment = 7'b1011111;
      4'b0111 : seven_segment = 7'b1110000;
      4'b1000 : seven_segment = 7'b1111111;
      4'b1001 : seven_segment = 7'b1111011;
      4'b1010 : seven_segment = 7'b1001111;
      4'b1011 : seven_segment = 7'b0001000;
      4'b1100 : seven_segment = 7'b1000111;
      4'b1101 : seven_segment = 7'b0000001;
      4'b1110 : seven_segment = 7'b0010101;
      4'b1111 : seven_segment = 7'b1110111;
    endcase
  end
endmodule