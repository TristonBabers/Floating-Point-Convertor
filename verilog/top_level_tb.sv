/* [top_level_tb]
 * - This tests the functionality of the floating point convertor by running 
 * multiple test cases on generic number conversions as well as edge-cases.
 *
 * @author Triston Babers
 * @contact Triston.Babers.Official@gmail.com
 */
module top_level_tb #(parameter DISPLAY_WIDTH = 12) ();
  logic [31:0]                   fp_binary;
  bit                            reset;
  bit                            clk;
  logic [DISPLAY_WIDTH-1:0][6:0] seven_segment_array;
  logic [31:0]                   fp_test_case;

  // Output in file "output_file.txt"
  integer out_file = $fopen("output_file.txt","w");

  initial begin
    // Input a floating point number here to convert it:
    fp_binary = 32'b0_01111111_10000000000000000000000; // 1.5

    reset = 1'b1;
    #10us;
    reset = 1'b0;
    # 10000us
    $fdisplay(out_file, "You entered: %b", fp_binary);
    $fdisplay(out_file, "Result: ");
    display_task (
      .segment_array(seven_segment_array)
    );
    $fdisplay(out_file, "");
    # 1us

    /*
    fp_binary = 32'b0_10000000_11000000000000000000000; // 3.5
    reset = 1'b1;
    #10us;
    reset = 1'b0;
    # 10000us
    $fdisplay(out_file, "Expected: 3.5");
    $fdisplay(out_file, "Result: ");
    display_task (
      .segment_array(seven_segment_array)
    );
    $fdisplay(out_file, "");
    # 1us
    fp_binary = 32'b0_10000010_10010011001100110011010; // 12.6
    reset = 1'b1;
    #10us;
    reset = 1'b0;
    # 10000us
    $fdisplay(out_file, "Expected: 12.6");
    $fdisplay(out_file, "Result: ");
    display_task (
      .segment_array(seven_segment_array)
    );
    $fdisplay(out_file, "");
    # 1us
    fp_binary = 32'b0_10000011_00111111110101110000101; // 19.98
    reset = 1'b1;
    #10us;
    reset = 1'b0;
    # 10000us
    $fdisplay(out_file, "Expected: 19.98");
    $fdisplay(out_file, "Result: ");
    display_task (
      .segment_array(seven_segment_array)
    );
    $fdisplay(out_file, "");
    # 1us
    fp_binary = 32'b0_10000111_01101101010000000000000; // 365.25
    reset = 1'b1;
    #10us;
    reset = 1'b0;
    # 10000us
    $fdisplay(out_file, "Expected: 365.25");
    $fdisplay(out_file, "Result: ");
    display_task (
      .segment_array(seven_segment_array)
    );
    $fdisplay(out_file, "");
    # 1us
    fp_binary = 32'b0_10001101_10010100010111100000000; // 25879.5
    reset = 1'b1;
    #10us;
    reset = 1'b0;
    # 10000us
    $fdisplay(out_file, "Expected: 25879.5");
    $fdisplay(out_file, "Result: ");
    display_task (
      .segment_array(seven_segment_array)
    );
    $fdisplay(out_file, "");
    # 1us
    fp_binary = 32'b0_10001111_11100010010000000000000; // 123456
    reset = 1'b1;
    #10us;
    reset = 1'b0;
    # 10000us
    $fdisplay(out_file, "Expected: 123456");
    $fdisplay(out_file, "Result: ");
    display_task (
      .segment_array(seven_segment_array)
    );
    $fdisplay(out_file, "");
    # 1us
    fp_binary = 32'b0_10010011_00101101011010000111000; // 1234567
    reset = 1'b1;
    #10us;
    reset = 1'b0;
    # 10000us
    $fdisplay(out_file, "Expected: 1234567");
    $fdisplay(out_file, "Result: ");
    display_task (
      .segment_array(seven_segment_array)
    );
    $fdisplay(out_file, "");
    # 1us

    // Exponent Norm
    fp_binary = 32'b0_10010111_10001000000000000000000; // 25690112
    reset = 1'b1;
    #10us;
    reset = 1'b0;
    # 10000us
    $fdisplay(out_file, "Expected: 25690112");
    $fdisplay(out_file, "Result: ");
    display_task (
      .segment_array(seven_segment_array)
    );
    $fdisplay(out_file, "");
    # 1us

    // Mantissa Tests
    fp_binary = 32'b0_01111100_00000000000000000000000; // 0.125
    reset = 1'b1;
    #10us;
    reset = 1'b0;
    # 10000us
    $fdisplay(out_file, "Expected: 0.125");
    $fdisplay(out_file, "Result: ");
    display_task (
      .segment_array(seven_segment_array)
    );
    $fdisplay(out_file, "");
    # 1us
    fp_binary = 32'b0_00100000_00000100000000000000000; // 2.56e-29
    reset = 1'b1;
    #10us;
    reset = 1'b0;
    # 10000us
    $fdisplay(out_file, "Expected: 2.56E-29");
    $fdisplay(out_file, "Result: ");
    display_task (
      .segment_array(seven_segment_array)
    );
    $fdisplay(out_file, "");
    # 1us

    // Maximimum Before Infinity
    fp_binary = 32'b0_11111110_11111111111111111111111; // 3.40E+38
    reset = 1'b1;
    #10us;
    reset = 1'b0;
    # 10000us
    $fdisplay(out_file, "Expected: 3.40E+28");
    $fdisplay(out_file, "Result: ");
    display_task (
      .segment_array(seven_segment_array)
    );
    $fdisplay(out_file, "");
    # 1us

    // Minimum Before Denormalized
    fp_binary = 32'b1_00000001_00000000000000000000000; // -1.17e-38
    reset = 1'b1;
    #10us;
    reset = 1'b0;
    # 10000us
    $fdisplay(out_file, "Expected: -1.17E-38");
    $fdisplay(out_file, "Result: ");
    display_task (
      .segment_array(seven_segment_array)
    );
    $fdisplay(out_file, "");
    # 1us

    // Denormalized
    fp_binary = 32'b0_00000000_00000000000000000000000; // 0
    reset = 1'b1;
    #10us;
    reset = 1'b0;
    # 10000us
    $fdisplay(out_file, "Expected: 0.000");
    $fdisplay(out_file, "Result: ");
    display_task (
      .segment_array(seven_segment_array)
    );
    $fdisplay(out_file, "");
    # 1us
    fp_binary = 32'b0_00000000_00000000000000000000001; // 1.401e-45
    reset = 1'b1;
    #10us;
    reset = 1'b0;
    # 10000us
    $fdisplay(out_file, "Expected: 1.401E-45");
    $fdisplay(out_file, "Result: ");
    display_task (
      .segment_array(seven_segment_array)
    );
    $fdisplay(out_file, "");
    # 1us

    // Closest Approximation of Pi
    fp_binary = 32'b0_10000000_10010010000111111011010; // 3.141592
    reset = 1'b1;
    #10us;
    reset = 1'b0;
    # 10000us
    $fdisplay(out_file, "Expected: 3.141592");
    $fdisplay(out_file, "Result: ");
    display_task (
      .segment_array(seven_segment_array)
    );
    $fdisplay(out_file, "");
    # 1us

    // Infinity
    fp_binary = 32'b0_11111111_00000000000000000000000; // +Infinity
    reset = 1'b1;
    #10us;
    reset = 1'b0;
    # 10000us
    $fdisplay(out_file, "Expected: InF");
    $fdisplay(out_file, "Result: ");
    display_task (
      .segment_array(seven_segment_array)
    );
    $fdisplay(out_file, "");
    # 1us
    fp_binary = 32'b1_11111111_00000000000000000000000; // -Infinity
    reset = 1'b1;
    #10us;
    reset = 1'b0;
    # 10000us
    $fdisplay(out_file, "Expected: -InF");
    $fdisplay(out_file, "Result: ");
    display_task (
      .segment_array(seven_segment_array)
    );
    $fdisplay(out_file, "");
    # 1us

    // NaN
    fp_binary = 32'b0_11111111_00000000000000000000001; // NaN
    reset = 1'b1;
    #10us;
    reset = 1'b0;
    # 10000us
    $fdisplay(out_file, "Expected: nAn");
    $fdisplay(out_file, "Result: ");
    display_task (
      .segment_array(seven_segment_array)
    );
    $fdisplay(out_file, "");
    # 1us
    // */
    
    $stop;
  end

  // Clock
  always begin
    #5000ns clk = 1'b1;       // tic 
    #5000ns clk = 1'b0;       // toc
  end

  // Device Under Test
  top_level #(.DISPLAY_WIDTH(DISPLAY_WIDTH)) top_level(
    .floating_point(fp_binary), .clk(clk), .reset(reset), .seven_segment_array(seven_segment_array)
  );
  
  // [display_task]
  task display_task (
    input[DISPLAY_WIDTH-1:0][6:0] segment_array
    );
    begin
      // segment A
      for (int i = DISPLAY_WIDTH - 1; i >= 0; i = i - 1) begin
        if(segment_array[i][6])
          $fwrite(out_file, " _ ");
        else
          $fwrite(out_file, "   ");		
        $fwrite(out_file, " ");
      end
      $fdisplay(out_file, "");

      // segments FGB
      for (int i = DISPLAY_WIDTH - 1; i >= 0; i = i - 1) begin
        if(segment_array[i][1]) $fwrite(out_file, "|");
        else $fwrite(out_file, " ");
        if(segment_array[i][0]) $fwrite(out_file, "_");
        else $fwrite(out_file, " ");
        if(segment_array[i][5]) $fwrite(out_file, "|");
        else $fwrite(out_file, " ");
        $fwrite(out_file, " ");
      end
      $fdisplay(out_file, "");

      // segments EDC
      for (int i = DISPLAY_WIDTH - 1; i >= -1; i = i - 1) begin
        if(segment_array[i][2]) $fwrite(out_file, "|");
        else $fwrite(out_file, " ");
        if(segment_array[i][3]) $fwrite(out_file, "_");
        else $fwrite(out_file, " ");
        if(segment_array[i][4]) $fwrite(out_file, "|");
        else $fwrite(out_file, " ");
        $fwrite(out_file, " ");
      end
      $fdisplay(out_file, "");
    end
  endtask
endmodule