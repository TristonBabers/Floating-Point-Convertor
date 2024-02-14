/* [fp_convertor]
 * - Takes in a 32-bit IEEE-754 floating point value and converts it into a base-10 decimal
 * floating point number. The converted floating point is rounded to the desired display width 
 * and returns that same number of 4-bit BCD digits as the output. The answer will NOT be rounded.

      Ex: DISPLAY_WIDTH = 8 bits, we found first non-zero in dibble[4]:
          - # # # # # . 0
          7 6 5 4 3 2 1 0

      Ex: DISPLAY_WIDTH = 8 bits, we found first non-zero in dibble[7]:
          - # . # # E 0 7 
          7 6 5 4 3 2 1 0
 *
 * @author Triston Babers
 * @contact Triston.Babers.Official@gmail.com
 */
module fp_convertor #(parameter DISPLAY_WIDTH = 8) (
  input [31:0] floating_point,
  input  clk,
         reset,
  output logic [DISPLAY_WIDTH-1:0][3:0] BCD
  );
  // Variables
  wire [22:0]        mantissa = floating_point[22: 0];
  wire [7:0]         exponent = floating_point[30: 23];
  wire               sign = floating_point[31: 31];
  wire signed [7:0]  unbiased_exponent = exponent - 7'd127;
  logic              sign_offset;
  logic [254:0]      addend;
  logic [277:0]      shifted_mantissa; // Because 255 exponent shift + 23 mantissa
  logic [277:0]      shifted_mantissa_expo;
  logic [3:0]        first_mantissa_bcd;
  logic [7:0]        mantissa_display_offset;
  logic signed [6:0] first_digit;
  logic [307:0]      addend_bcd; // Because 4 * 77 decimal places = 308
  logic signed [9:0] itr;
  logic signed [9:0] next_itr;
 
  // State Machine
  typedef enum {START, RESET, CALC_ADDEND_FDIGIT, DRAW_ADDEND, DRAW_EXPONENT, DRAW_EXPO_ADDEND, DRAW_EXPO_MANTISSA, DRAW_MANTISSA, INF_NAN, DENORM, NORM_MANTISSA, NORM_ADDEND, NORM_BETWEEN, DOUBLE_DABBLE, CALC_MANTISSA_FDIGIT, DONE} fp_states;
  fp_states present_state, next_state;
  always_ff @(posedge clk) begin
    if(reset) begin
      present_state <= RESET;
    end else begin
      present_state <= next_state;
      itr <= next_itr;
    end
  end
  
  // Logic
  always_latch begin
    // Default to RESET state
    next_state = RESET;
    next_itr = 0;
    case (present_state)
    RESET: begin
      next_state = START;
      addend = 0;
      shifted_mantissa = 0; 
      shifted_mantissa_expo = 0;
      first_mantissa_bcd = 0;
      mantissa_display_offset = 0;
      first_digit = 0;
      addend_bcd = 0;
      // Make all values "." by default
      BCD = {DISPLAY_WIDTH{4'b1011}}; // "."
    end
    START: begin
      // Negative/Positive Sign
      if (sign == 0) begin
        sign_offset = 0;
      end else begin
        BCD[DISPLAY_WIDTH - 1] = 4'b1101;
        sign_offset = 1;
      end
      
      if (exponent == 8'b11111111)
        next_state = INF_NAN;
      else if (exponent == 8'b00000000)
        next_state = DENORM;
      else if (unbiased_exponent >= 23)
        next_state = NORM_ADDEND;
      else if (unbiased_exponent >= 0)
        next_state = NORM_BETWEEN;
      else // if (unbiased_exponent < 0)
        next_state = NORM_MANTISSA;
    end
    INF_NAN: begin
      // Special Cases
      if (mantissa == 23'b00000000000000000000000) begin
        // Infinity Case
        BCD[DISPLAY_WIDTH - 1 - sign_offset] = 4'b0001; // "I" but really "1"
        BCD[DISPLAY_WIDTH - 2 - sign_offset] = 4'b1110; // "N"
        BCD[DISPLAY_WIDTH - 3 - sign_offset] = 4'b1100; // "F"
      end else begin
        // NaN Case
        BCD[DISPLAY_WIDTH - 1] = 4'b1110; // "N"
        BCD[DISPLAY_WIDTH - 2] = 4'b1111; // "A"
        BCD[DISPLAY_WIDTH - 3] = 4'b1110; // "N"
      end
      next_state = DONE;
    end
    DENORM: begin
      // The same as NORM_MANTISSA, but leading zero and set to 2^(-126)
      if (itr == 0) begin
        shifted_mantissa[255 - 126 +: 23] = mantissa[22:0];
        shifted_mantissa[278 - 126] = 0; // Leading 0

        addend = 0;
        addend_bcd = 0;
        next_itr = 1;
        next_state = DENORM;
      end else begin
        // Wait a cycle to copy shifted mantissa
        shifted_mantissa_expo[277:0] = shifted_mantissa[277:0];
        
        next_itr = 1;
        mantissa_display_offset = 1;
        next_state = CALC_MANTISSA_FDIGIT;
      end
    end
    NORM_ADDEND: begin
      // Positive Exponents - Part 1 (entire mantissa gets shifted to addend)
      shifted_mantissa <= 0;
      addend[unbiased_exponent - 1 -: 23] = mantissa;
      addend[unbiased_exponent] = 1; // Leading 1
      mantissa_display_offset = DISPLAY_WIDTH; // Don't draw mantissa

      next_itr = 0;
      addend_bcd = 0;
      next_state = DOUBLE_DABBLE;
    end
    DOUBLE_DABBLE: begin
      /* Calculate Addend (Double-Dabble) - Part 1
      * Uses Double-Dabble to calculate the addend BCD.
      * Source: https://www.realdigital.org/doc/6dae6583570fd816d1d675b93578203d
      */
      if (itr < 255) begin
        next_itr = itr + 1;
        if (addend_bcd[3:0]     > 4) addend_bcd[3:0]     = addend_bcd[3:0] + 3;
        if (addend_bcd[7:4]     > 4) addend_bcd[7:4]     = addend_bcd[7:4] + 3;
        if (addend_bcd[11:8]    > 4) addend_bcd[11:8]    = addend_bcd[11:8] + 3;
        if (addend_bcd[15:12]   > 4) addend_bcd[15:12]   = addend_bcd[15:12] + 3;
        if (addend_bcd[19:16]   > 4) addend_bcd[19:16]   = addend_bcd[19:16] + 3;
        if (addend_bcd[23:20]   > 4) addend_bcd[23:20]   = addend_bcd[23:20] + 3;
        if (addend_bcd[27:24]   > 4) addend_bcd[27:24]   = addend_bcd[27:24] + 3;
        if (addend_bcd[31:28]   > 4) addend_bcd[31:28]   = addend_bcd[31:28] + 3;
        if (addend_bcd[35:32]   > 4) addend_bcd[35:32]   = addend_bcd[35:32] + 3;
        if (addend_bcd[39:36]   > 4) addend_bcd[39:36]   = addend_bcd[39:36] + 3;
        if (addend_bcd[43:40]   > 4) addend_bcd[43:40]   = addend_bcd[43:40] + 3;
        if (addend_bcd[47:44]   > 4) addend_bcd[47:44]   = addend_bcd[47:44] + 3;
        if (addend_bcd[51:48]   > 4) addend_bcd[51:48]   = addend_bcd[51:48] + 3;
        if (addend_bcd[55:52]   > 4) addend_bcd[55:52]   = addend_bcd[55:52] + 3;
        if (addend_bcd[59:56]   > 4) addend_bcd[59:56]   = addend_bcd[59:56] + 3;
        if (addend_bcd[63:60]   > 4) addend_bcd[63:60]   = addend_bcd[63:60] + 3;
        if (addend_bcd[67:64]   > 4) addend_bcd[67:64]   = addend_bcd[67:64] + 3;
        if (addend_bcd[71:68]   > 4) addend_bcd[71:68]   = addend_bcd[71:68] + 3;
        if (addend_bcd[75:72]   > 4) addend_bcd[75:72]   = addend_bcd[75:72] + 3;
        if (addend_bcd[79:76]   > 4) addend_bcd[79:76]   = addend_bcd[79:76] + 3;
        if (addend_bcd[83:80]   > 4) addend_bcd[83:80]   = addend_bcd[83:80] + 3;
        if (addend_bcd[87:84]   > 4) addend_bcd[87:84]   = addend_bcd[87:84] + 3;
        if (addend_bcd[91:88]   > 4) addend_bcd[91:88]   = addend_bcd[91:88] + 3;
        if (addend_bcd[95:92]   > 4) addend_bcd[95:92]   = addend_bcd[95:92] + 3;
        if (addend_bcd[99:96]   > 4) addend_bcd[99:96]   = addend_bcd[99:96] + 3;
        if (addend_bcd[103:100] > 4) addend_bcd[103:100] = addend_bcd[103:100] + 3;
        if (addend_bcd[107:104] > 4) addend_bcd[107:104] = addend_bcd[107:104] + 3;
        if (addend_bcd[111:108] > 4) addend_bcd[111:108] = addend_bcd[111:108] + 3;
        if (addend_bcd[115:112] > 4) addend_bcd[115:112] = addend_bcd[115:112] + 3;
        if (addend_bcd[119:116] > 4) addend_bcd[119:116] = addend_bcd[119:116] + 3;
        if (addend_bcd[123:120] > 4) addend_bcd[123:120] = addend_bcd[123:120] + 3;
        if (addend_bcd[127:124] > 4) addend_bcd[127:124] = addend_bcd[127:124] + 3;
        if (addend_bcd[131:128] > 4) addend_bcd[131:128] = addend_bcd[131:128] + 3;
        if (addend_bcd[135:132] > 4) addend_bcd[135:132] = addend_bcd[135:132] + 3;
        if (addend_bcd[139:136] > 4) addend_bcd[139:136] = addend_bcd[139:136] + 3;
        if (addend_bcd[143:140] > 4) addend_bcd[143:140] = addend_bcd[143:140] + 3;
        if (addend_bcd[147:144] > 4) addend_bcd[147:144] = addend_bcd[147:144] + 3;
        if (addend_bcd[151:148] > 4) addend_bcd[151:148] = addend_bcd[151:148] + 3;
        if (addend_bcd[155:152] > 4) addend_bcd[155:152] = addend_bcd[155:152] + 3;
        if (addend_bcd[159:156] > 4) addend_bcd[159:156] = addend_bcd[159:156] + 3;
        if (addend_bcd[163:160] > 4) addend_bcd[163:160] = addend_bcd[163:160] + 3;
        if (addend_bcd[167:164] > 4) addend_bcd[167:164] = addend_bcd[167:164] + 3;
        if (addend_bcd[171:168] > 4) addend_bcd[171:168] = addend_bcd[171:168] + 3;
        if (addend_bcd[175:172] > 4) addend_bcd[175:172] = addend_bcd[175:172] + 3;
        if (addend_bcd[179:176] > 4) addend_bcd[179:176] = addend_bcd[179:176] + 3;
        if (addend_bcd[183:180] > 4) addend_bcd[183:180] = addend_bcd[183:180] + 3;
        if (addend_bcd[187:184] > 4) addend_bcd[187:184] = addend_bcd[187:184] + 3;
        if (addend_bcd[191:188] > 4) addend_bcd[191:188] = addend_bcd[191:188] + 3;
        if (addend_bcd[195:192] > 4) addend_bcd[195:192] = addend_bcd[195:192] + 3;
        if (addend_bcd[199:196] > 4) addend_bcd[199:196] = addend_bcd[199:196] + 3;
        if (addend_bcd[203:200] > 4) addend_bcd[203:200] = addend_bcd[203:200] + 3;
        if (addend_bcd[207:204] > 4) addend_bcd[207:204] = addend_bcd[207:204] + 3;
        if (addend_bcd[211:208] > 4) addend_bcd[211:208] = addend_bcd[211:208] + 3;
        if (addend_bcd[215:212] > 4) addend_bcd[215:212] = addend_bcd[215:212] + 3;
        if (addend_bcd[219:216] > 4) addend_bcd[219:216] = addend_bcd[219:216] + 3;
        if (addend_bcd[223:220] > 4) addend_bcd[223:220] = addend_bcd[223:220] + 3;
        if (addend_bcd[227:224] > 4) addend_bcd[227:224] = addend_bcd[227:224] + 3;
        if (addend_bcd[231:228] > 4) addend_bcd[231:228] = addend_bcd[231:228] + 3;
        if (addend_bcd[235:232] > 4) addend_bcd[235:232] = addend_bcd[235:232] + 3;
        if (addend_bcd[239:236] > 4) addend_bcd[239:236] = addend_bcd[239:236] + 3;
        if (addend_bcd[243:240] > 4) addend_bcd[243:240] = addend_bcd[243:240] + 3;
        if (addend_bcd[247:244] > 4) addend_bcd[247:244] = addend_bcd[247:244] + 3;
        if (addend_bcd[251:248] > 4) addend_bcd[251:248] = addend_bcd[251:248] + 3;
        if (addend_bcd[255:252] > 4) addend_bcd[255:252] = addend_bcd[255:252] + 3;
        if (addend_bcd[259:256] > 4) addend_bcd[259:256] = addend_bcd[259:256] + 3;
        if (addend_bcd[263:260] > 4) addend_bcd[263:260] = addend_bcd[263:260] + 3;
        if (addend_bcd[267:264] > 4) addend_bcd[267:264] = addend_bcd[267:264] + 3;
        if (addend_bcd[271:268] > 4) addend_bcd[271:268] = addend_bcd[271:268] + 3;
        if (addend_bcd[275:272] > 4) addend_bcd[275:272] = addend_bcd[275:272] + 3;
        if (addend_bcd[279:276] > 4) addend_bcd[279:276] = addend_bcd[279:276] + 3;
        if (addend_bcd[283:280] > 4) addend_bcd[283:280] = addend_bcd[283:280] + 3;
        if (addend_bcd[287:284] > 4) addend_bcd[287:284] = addend_bcd[287:284] + 3;
        if (addend_bcd[291:288] > 4) addend_bcd[291:288] = addend_bcd[291:288] + 3;
        if (addend_bcd[295:292] > 4) addend_bcd[295:292] = addend_bcd[295:292] + 3;
        if (addend_bcd[299:296] > 4) addend_bcd[299:296] = addend_bcd[299:296] + 3;
        if (addend_bcd[303:300] > 4) addend_bcd[303:300] = addend_bcd[303:300] + 3;
        if (addend_bcd[307:304] > 4) addend_bcd[307:304] = addend_bcd[307:304] + 3;
        addend_bcd = {addend_bcd[306:0], addend[254-itr]};    //Shift one bit, and shift in proper bit from input
        next_state = DOUBLE_DABBLE; // Repeat State
      end else begin
        next_itr = 307;
        next_state = CALC_ADDEND_FDIGIT;
      end
    end
    NORM_BETWEEN: begin
      // Positive Exponents - Part 2 (part of mantissa gets shifted to addend)
      shifted_mantissa[277:0] = 0;
      addend = mantissa >> 23 - unbiased_exponent;
      addend[unbiased_exponent] = 1; // Leading 1

      next_itr = 0;
      addend_bcd = 0;
      next_state = DOUBLE_DABBLE;
    end
    CALC_ADDEND_FDIGIT: begin
      shifted_mantissa[255 +: 23] = mantissa << unbiased_exponent;
      // First Digit of Addend Calculation
      if (itr >= 0) begin
        first_digit = itr >> 2; // itr / 4
        if (addend_bcd[itr] == 1'b1)
          next_itr = -1;
        else
          next_itr = itr - 1;
        next_state = CALC_ADDEND_FDIGIT; // Repeat State
      end else begin
        if (first_digit > DISPLAY_WIDTH - 1 - sign_offset)
          next_state = DRAW_EXPONENT;
        else begin
          next_state = DRAW_ADDEND;
          next_itr = DISPLAY_WIDTH - 1 - sign_offset;
        end
      end
    end
    DRAW_EXPONENT: begin
      // LUT for exponent Notation
      case (first_digit)
      -1: begin
        BCD[1] = 4'b0000;
        BCD[0] = 4'b0001;
      end
      -2: begin
        BCD[1] = 4'b0000;
        BCD[0] = 4'b0010;
      end
      -3: begin
        BCD[1] = 4'b0000;
        BCD[0] = 4'b0011;
      end
      -4: begin
        BCD[1] = 4'b0000;
        BCD[0] = 4'b0100;
      end
      -5: begin
        BCD[1] = 4'b0000;
        BCD[0] = 4'b0101;
      end
      -6: begin
        BCD[1] = 4'b0000;
        BCD[0] = 4'b0110;
      end
      -7: begin
        BCD[1] = 4'b0000;
        BCD[0] = 4'b0111;
      end
      -8: begin
        BCD[1] = 4'b0000;
        BCD[0] = 4'b1000;
      end
      -9: begin
        BCD[1] = 4'b0000;
        BCD[0] = 4'b1001;
      end
      -10: begin
        BCD[1] = 4'b0001;
        BCD[0] = 4'b0000;
      end
      -11: begin
        BCD[1] = 4'b0001;
        BCD[0] = 4'b0001;
      end
      -12: begin
        BCD[1] = 4'b0001;
        BCD[0] = 4'b0010;
      end
      -13: begin
        BCD[1] = 4'b0001;
        BCD[0] = 4'b0011;
      end
      -14: begin
        BCD[1] = 4'b0001;
        BCD[0] = 4'b0100;
      end
      -15: begin
        BCD[1] = 4'b0001;
        BCD[0] = 4'b0101;
      end
      -16: begin
        BCD[1] = 4'b0001;
        BCD[0] = 4'b0110;
      end
      -17: begin
        BCD[1] = 4'b0001;
        BCD[0] = 4'b0111;
      end
      -18: begin
        BCD[1] = 4'b0001;
        BCD[0] = 4'b1000;
      end
      -19: begin
        BCD[1] = 4'b0001;
        BCD[0] = 4'b1001;
      end
      -20: begin
        BCD[1] = 4'b0010;
        BCD[0] = 4'b0000;
      end
      -21: begin
        BCD[1] = 4'b0010;
        BCD[0] = 4'b0001;
      end
      -22: begin
        BCD[1] = 4'b0010;
        BCD[0] = 4'b0010;
      end
      -23: begin
        BCD[1] = 4'b0010;
        BCD[0] = 4'b0011;
      end
      -24: begin
        BCD[1] = 4'b0010;
        BCD[0] = 4'b0100;
      end
      -25: begin
        BCD[1] = 4'b0010;
        BCD[0] = 4'b0101;
      end
      -26: begin
        BCD[1] = 4'b0010;
        BCD[0] = 4'b0110;
      end
      -27: begin
        BCD[1] = 4'b0010;
        BCD[0] = 4'b0111;
      end
      -28: begin
        BCD[1] = 4'b0010;
        BCD[0] = 4'b1000;
      end
      -29: begin
        BCD[1] = 4'b0010;
        BCD[0] = 4'b1001;
      end
      -30: begin
        BCD[1] = 4'b0011;
        BCD[0] = 4'b0000;
      end
      -31: begin
        BCD[1] = 4'b0011;
        BCD[0] = 4'b0001;
      end
      -32: begin
        BCD[1] = 4'b0011;
        BCD[0] = 4'b0010;
      end
      -33: begin
        BCD[1] = 4'b0011;
        BCD[0] = 4'b0011;
      end
      -34: begin
        BCD[1] = 4'b0011;
        BCD[0] = 4'b0100;
      end
      -35: begin
        BCD[1] = 4'b0011;
        BCD[0] = 4'b0101;
      end
      -36: begin
        BCD[1] = 4'b0011;
        BCD[0] = 4'b0110;
      end
      -37: begin
        BCD[1] = 4'b0011;
        BCD[0] = 4'b0111;
      end
      -38: begin
        BCD[1] = 4'b0011;
        BCD[0] = 4'b1000;
      end
      -39: begin
        BCD[1] = 4'b0011;
        BCD[0] = 4'b1001;
      end
      -40: begin
        BCD[1] = 4'b0100;
        BCD[0] = 4'b0000;
      end
      -41: begin
        BCD[1] = 4'b0100;
        BCD[0] = 4'b0001;
      end
      -42: begin
        BCD[1] = 4'b0100;
        BCD[0] = 4'b0010;
      end
      -43: begin
        BCD[1] = 4'b0100;
        BCD[0] = 4'b0011;
      end
      -44: begin
        BCD[1] = 4'b0100;
        BCD[0] = 4'b0100;
      end
      -45: begin
        BCD[1] = 4'b0100;
        BCD[0] = 4'b0101;
      end
      -46: begin
        BCD[1] = 4'b0100;
        BCD[0] = 4'b0110;
      end
      -47: begin
        BCD[1] = 4'b0100;
        BCD[0] = 4'b0111;
      end
      -48: begin
        BCD[1] = 4'b0100;
        BCD[0] = 4'b1000;
      end
      -49: begin
        BCD[1] = 4'b0100;
        BCD[0] = 4'b1001;
      end
      -50: begin
        BCD[1] = 4'b0101;
        BCD[0] = 4'b0000;
      end
      -51: begin
        BCD[1] = 4'b0101;
        BCD[0] = 4'b0001;
      end
      -52: begin
        BCD[1] = 4'b0101;
        BCD[0] = 4'b0010;
      end
      -53: begin
        BCD[1] = 4'b0101;
        BCD[0] = 4'b0011;
      end
      -54: begin
        BCD[1] = 4'b0101;
        BCD[0] = 4'b0100;
      end
      -55: begin
        BCD[1] = 4'b0101;
        BCD[0] = 4'b0101;
      end
      -56: begin
        BCD[1] = 4'b0101;
        BCD[0] = 4'b0110;
      end
      -57: begin
        BCD[1] = 4'b0101;
        BCD[0] = 4'b0111;
      end
      -58: begin
        BCD[1] = 4'b0101;
        BCD[0] = 4'b1000;
      end
      -59: begin
        BCD[1] = 4'b0101;
        BCD[0] = 4'b1001;
      end
      -60: begin
        BCD[1] = 4'b0110;
        BCD[0] = 4'b0000;
      end
      -61: begin
        BCD[1] = 4'b0110;
        BCD[0] = 4'b0001;
      end
      -62: begin
        BCD[1] = 4'b0110;
        BCD[0] = 4'b0010;
      end
      -63: begin
        BCD[1] = 4'b0110;
        BCD[0] = 4'b0011;
      end
      -64: begin
        BCD[1] = 4'b0110;
        BCD[0] = 4'b0011;
      end
      0: begin
        BCD[1] = 4'b0000;
        BCD[0] = 4'b0000;
      end
      1: begin
        BCD[1] = 4'b0000;
        BCD[0] = 4'b0001;
      end
      2: begin
        BCD[1] = 4'b0000;
        BCD[0] = 4'b0010;
      end
      3: begin
        BCD[1] = 4'b0000;
        BCD[0] = 4'b0011;
      end
      4: begin
        BCD[1] = 4'b0000;
        BCD[0] = 4'b0100;
      end
      5: begin
        BCD[1] = 4'b0000;
        BCD[0] = 4'b0101;
      end
      6: begin
        BCD[1] = 4'b0000;
        BCD[0] = 4'b0110;
      end
      7: begin
        BCD[1] = 4'b0000;
        BCD[0] = 4'b0111;
      end
      8: begin
        BCD[1] = 4'b0000;
        BCD[0] = 4'b1000;
      end
      9: begin
        BCD[1] = 4'b0000;
        BCD[0] = 4'b1001;
      end
      10: begin
        BCD[1] = 4'b0001;
        BCD[0] = 4'b0000;
      end
      11: begin
        BCD[1] = 4'b0001;
        BCD[0] = 4'b0001;
      end
      12: begin
        BCD[1] = 4'b0001;
        BCD[0] = 4'b0010;
      end
      13: begin
        BCD[1] = 4'b0001;
        BCD[0] = 4'b0011;
      end
      14: begin
        BCD[1] = 4'b0001;
        BCD[0] = 4'b0100;
      end
      15: begin
        BCD[1] = 4'b0001;
        BCD[0] = 4'b0101;
      end
      16: begin
        BCD[1] = 4'b0001;
        BCD[0] = 4'b0110;
      end
      17: begin
        BCD[1] = 4'b0001;
        BCD[0] = 4'b0111;
      end
      18: begin
        BCD[1] = 4'b0001;
        BCD[0] = 4'b1000;
      end
      19: begin
        BCD[1] = 4'b0001;
        BCD[0] = 4'b1001;
      end
      20: begin
        BCD[1] = 4'b0010;
        BCD[0] = 4'b0000;
      end
      21: begin
        BCD[1] = 4'b0010;
        BCD[0] = 4'b0001;
      end
      22: begin
        BCD[1] = 4'b0010;
        BCD[0] = 4'b0010;
      end
      23: begin
        BCD[1] = 4'b0010;
        BCD[0] = 4'b0011;
      end
      24: begin
        BCD[1] = 4'b0010;
        BCD[0] = 4'b0100;
      end
      25: begin
        BCD[1] = 4'b0010;
        BCD[0] = 4'b0101;
      end
      26: begin
        BCD[1] = 4'b0010;
        BCD[0] = 4'b0110;
      end
      27: begin
        BCD[1] = 4'b0010;
        BCD[0] = 4'b0111;
      end
      28: begin
        BCD[1] = 4'b0010;
        BCD[0] = 4'b1000;
      end
      29: begin
        BCD[1] = 4'b0010;
        BCD[0] = 4'b1001;
      end
      30: begin
        BCD[1] = 4'b0011;
        BCD[0] = 4'b0000;
      end
      31: begin
        BCD[1] = 4'b0011;
        BCD[0] = 4'b0001;
      end
      32: begin
        BCD[1] = 4'b0011;
        BCD[0] = 4'b0010;
      end
      33: begin
        BCD[1] = 4'b0011;
        BCD[0] = 4'b0011;
      end
      34: begin
        BCD[1] = 4'b0011;
        BCD[0] = 4'b0100;
      end
      35: begin
        BCD[1] = 4'b0011;
        BCD[0] = 4'b0101;
      end
      36: begin
        BCD[1] = 4'b0011;
        BCD[0] = 4'b0110;
      end
      37: begin
        BCD[1] = 4'b0011;
        BCD[0] = 4'b0111;
      end
      38: begin
        BCD[1] = 4'b0011;
        BCD[0] = 4'b1000;
      end
      39: begin
        BCD[1] = 4'b0011;
        BCD[0] = 4'b1001;
      end
      40: begin
        BCD[1] = 4'b0100;
        BCD[0] = 4'b0000;
      end
      41: begin
        BCD[1] = 4'b0100;
        BCD[0] = 4'b0001;
      end
      42: begin
        BCD[1] = 4'b0100;
        BCD[0] = 4'b0010;
      end
      43: begin
        BCD[1] = 4'b0100;
        BCD[0] = 4'b0011;
      end
      44: begin
        BCD[1] = 4'b0100;
        BCD[0] = 4'b0100;
      end
      45: begin
        BCD[1] = 4'b0100;
        BCD[0] = 4'b0101;
      end
      46: begin
        BCD[1] = 4'b0100;
        BCD[0] = 4'b0110;
      end
      47: begin
        BCD[1] = 4'b0100;
        BCD[0] = 4'b0111;
      end
      48: begin
        BCD[1] = 4'b0100;
        BCD[0] = 4'b1000;
      end
      49: begin
        BCD[1] = 4'b0100;
        BCD[0] = 4'b1001;
      end
      50: begin
        BCD[1] = 4'b0101;
        BCD[0] = 4'b0000;
      end
      51: begin
        BCD[1] = 4'b0101;
        BCD[0] = 4'b0001;
      end
      52: begin
        BCD[1] = 4'b0101;
        BCD[0] = 4'b0010;
      end
      53: begin
        BCD[1] = 4'b0101;
        BCD[0] = 4'b0011;
      end
      54: begin
        BCD[1] = 4'b0101;
        BCD[0] = 4'b0100;
      end
      55: begin
        BCD[1] = 4'b0101;
        BCD[0] = 4'b0101;
      end
      56: begin
        BCD[1] = 4'b0101;
        BCD[0] = 4'b0110;
      end
      57: begin
        BCD[1] = 4'b0101;
        BCD[0] = 4'b0111;
      end
      58: begin
        BCD[1] = 4'b0101;
        BCD[0] = 4'b1000;
      end
      59: begin
        BCD[1] = 4'b0101;
        BCD[0] = 4'b1001;
      end
      60: begin
        BCD[1] = 4'b0110;
        BCD[0] = 4'b0000;
      end
      61: begin
        BCD[1] = 4'b0110;
        BCD[0] = 4'b0001;
      end
      62: begin
        BCD[1] = 4'b0110;
        BCD[0] = 4'b0010;
      end
      63: begin
        BCD[1] = 4'b0110;
        BCD[0] = 4'b0011;
      end
      endcase
      if (unbiased_exponent > 0) begin
        BCD[2] = 4'b1010; // "e"

        next_itr = DISPLAY_WIDTH - 4;
        next_state = DRAW_EXPO_ADDEND;
        mantissa_display_offset = DISPLAY_WIDTH; // Don't draw mantissa
      end else begin
        BCD[3] = 4'b1010; // "e"
        BCD[2] = 4'b1101; // "-"
        
        next_itr = DISPLAY_WIDTH - 3 - sign_offset;
        next_state = DRAW_EXPO_MANTISSA;
      end
    end
    DRAW_EXPO_ADDEND: begin
      BCD[DISPLAY_WIDTH - 1 - sign_offset] = addend_bcd[first_digit * 4 +: 4];
      BCD[DISPLAY_WIDTH - 2 - sign_offset] = 4'b1011; // "."
      // Draw Addend behind decimal point for scientific notation
      /* itr starts at DISPLAY_WIDTH - 4 and stops at 2, this is a constant
       * because if the display is 6 then there will be [+][#][.][e][#][#].
       * So that is the cut-off for drawing digits behind the decimal.
       */
      if (itr > 2) begin
        BCD[itr] = addend_bcd[$signed((first_digit + itr - DISPLAY_WIDTH + 3) * 4) +: 4];
        next_itr = itr - 1;
        next_state = DRAW_EXPO_ADDEND; // Repeat State
      end else begin
        next_state = DONE;
      end
    end
    DRAW_ADDEND: begin
      // Convert binary to BCD
      mantissa_display_offset = first_digit + 2 + sign_offset; // Draw Mantissa after decimal point
      BCD[DISPLAY_WIDTH - first_digit - 2 - sign_offset] = 4'b1011; // "."
      // Draw Addend in front
      if (itr >= $signed(DISPLAY_WIDTH - 1 - sign_offset - first_digit)) begin
        BCD[itr] = addend_bcd[$signed((first_digit + itr - DISPLAY_WIDTH + 1 + sign_offset) * 4) +: 4];
        next_itr = itr - 1;
        next_state = DRAW_ADDEND; // Repeat State
      end else begin
        next_state = DRAW_MANTISSA;
        next_itr = DISPLAY_WIDTH - 1;
      end
    end
    DRAW_MANTISSA: begin
     /* Draw Mantissa
      * - We add together the mantissa << 1 + mantissa << 3 in order to simulate multiplying
      * by 4'b1010, which is 10 in decimal. Then we save the overflow into the BCD output register
      * and overwrite the shifted mantissa with the sum. I recommend checking my project page on
      * TristonBabers.com for more info.
      */
      if (itr >= 0) begin
        {BCD[itr - mantissa_display_offset], shifted_mantissa} = (shifted_mantissa << 1) + (shifted_mantissa << 3);
        next_itr = itr - 1;
        next_state = DRAW_MANTISSA; // Repeat State
      end else begin
        next_state = DONE;
      end
    end
    NORM_MANTISSA: begin
      if (itr == 0) begin
        // Negative Exponents (use the whole mantissa)
        shifted_mantissa[255 + unbiased_exponent +: 23] = mantissa[22:0];
        shifted_mantissa[278 + unbiased_exponent] = 1; // Leading 1

        addend = 0;
        addend_bcd = 0;
        next_itr = 1;
        next_state = NORM_MANTISSA;
      end else begin
        // Wait a cycle to copy shifted mantissa
        shifted_mantissa_expo[277:0] = shifted_mantissa[277:0];
        
        next_itr = 1;
        mantissa_display_offset = 1;
        next_state = CALC_MANTISSA_FDIGIT;
      end
    end
    CALC_MANTISSA_FDIGIT: begin
      if (itr < 50) begin
        {first_mantissa_bcd, shifted_mantissa_expo} = (shifted_mantissa_expo << 1) + (shifted_mantissa_expo << 3);
        next_itr = itr + 1;
        next_state = CALC_MANTISSA_FDIGIT; // Repeat State
        if (first_mantissa_bcd != 0) begin
          first_digit = -itr;
          next_itr = 50; // Break
        end
      end else begin
        if (first_digit <= $signed(-DISPLAY_WIDTH + 4 - sign_offset)) begin
          BCD[DISPLAY_WIDTH - 1 - sign_offset] = first_mantissa_bcd; // Draw Mantissa in Scientific Notation
          BCD[DISPLAY_WIDTH - 2 - sign_offset] = 4'b1011; // "."
          next_state = DRAW_EXPONENT;
        end else begin
          mantissa_display_offset = 2 + sign_offset; // Draw Mantissa after decimal point
          BCD[DISPLAY_WIDTH - 1 - sign_offset] = 4'b0000; // "0"
          BCD[DISPLAY_WIDTH - 2 - sign_offset] = 4'b1011; // "."

          next_itr = DISPLAY_WIDTH - 1;
          next_state = DRAW_MANTISSA;
        end
      end
    end
    DRAW_EXPO_MANTISSA: begin
      if (itr >= 4) begin
        {BCD[itr], shifted_mantissa_expo} = (shifted_mantissa_expo << 1) + (shifted_mantissa_expo << 3);
        next_itr = itr - 1;
        next_state = DRAW_EXPO_MANTISSA; // Repeat State
      end else begin
        next_state = DONE;
      end
    end
    DONE: begin
      next_state = DONE;
    end
    endcase
  end
endmodule