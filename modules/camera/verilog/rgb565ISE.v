module rgb5652GrayscaleIse (input  wire [31:0] pixelWord,
                            output wire [15:0] grayscalePixelWord);

  /* we compensate here for the big/little endian problem */

  //wire [15:0] s_grayScaleValues;
  wire [7:0] pixel1Grayscale,
             pixel2Grayscale;
  /*
  assign grayscalePixelWord = {pixel2Grayscale[7:3],  // R2
                               pixel2Grayscale[7:2],  // G2
                               pixel2Grayscale[7:3],  // B2
                               pixel1Grayscale[7:3],  // R1
                               pixel1Grayscale[7:2],  // G1
                               pixel1Grayscale[7:3]}; // B1
  */
  assign grayscalePixelWord = {pixel2Grayscale,
                               pixel1Grayscale};
  rgb565Grayscale pixel1 (.rgb565({pixelWord[15:0]}),
                          //.grayscale(s_grayScaleValues[23:16]));
                          .grayscale(pixel1Grayscale));
  rgb565Grayscale pixel2 (.rgb565({pixelWord[31:16]}),
                          //.grayscale(s_grayScaleValues[31:24]));
                          .grayscale(pixel2Grayscale));
endmodule
