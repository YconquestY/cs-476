#include <stdio.h>
#include <ov7670.h>
#include <swap.h>
#include <vga.h>


int main () {
  volatile uint16_t rgb565[640*480];
  volatile uint8_t grayscale[640*480];
  volatile uint32_t result, cycles,stall,idle;
  volatile unsigned int *vga = (unsigned int *) 0X50000020;
  camParameters camParams;
  vga_clear();
  
  printf("Initialising camera (this takes up to 3 seconds)!\n" );
  camParams = initOv7670(VGA);
  printf("Done!\n" );
  printf("NrOfPixels : %d\n", camParams.nrOfPixelsPerLine );
  result = (camParams.nrOfPixelsPerLine <= 320) ? camParams.nrOfPixelsPerLine | 0x80000000 : camParams.nrOfPixelsPerLine;
  vga[0] = swap_u32(result);
  printf("NrOfLines  : %d\n", camParams.nrOfLinesPerImage );
  result =  (camParams.nrOfLinesPerImage <= 240) ? camParams.nrOfLinesPerImage | 0x80000000 : camParams.nrOfLinesPerImage;
  vga[1] = swap_u32(result);
  printf("PCLK (kHz) : %d\n", camParams.pixelClockInkHz );
  printf("FPS        : %d\n", camParams.framesPerSecond );
  uint32_t * rgb = (uint32_t *) &rgb565[0];
  uint32_t grayPixels;
  vga[2] = swap_u32(2);
  vga[3] = swap_u32((uint32_t) &grayscale[0]);
  while(1) {
    uint32_t * gray = (uint32_t *) &grayscale[0];
    takeSingleImageBlocking((uint32_t) &rgb565[0]);
    asm volatile ("l.nios_rrr r0,r0,%[in2],0xC"::[in2]"r"(7)); // enable counters 0,1,2
    for (int line = 0; line < camParams.nrOfLinesPerImage; line++) {
      for (int pixel = 0; pixel < camParams.nrOfPixelsPerLine; pixel += 4) { // screen size 640 x 480: multiple of 4
        uint16_t pA0 = swap_u16(rgb565[line*camParams.nrOfPixelsPerLine+pixel  ]);
        uint16_t pA1 = swap_u16(rgb565[line*camParams.nrOfPixelsPerLine+pixel+1]);
        uint16_t pB0 = swap_u16(rgb565[line*camParams.nrOfPixelsPerLine+pixel+2]);
        uint16_t pB1 = swap_u16(rgb565[line*camParams.nrOfPixelsPerLine+pixel+3]);
        /*
        uint32_t red1 = ((rgb >> 11) & 0x1F) << 3;
        uint32_t green1 = ((rgb >> 5) & 0x3F) << 2;
        uint32_t blue1 = (rgb & 0x1F) << 3;
        uint32_t gray = ((red1*54+green1*183+blue1*19) >> 8)&0xFF;
        */
        uint32_t gray = 0;
        uint32_t valueA = ((uint32_t) pA0) << 16 | (uint32_t) pA1;
        uint32_t valueB = ((uint32_t) pB0) << 16 | (uint32_t) pB1;
        asm volatile ("l.nios_rrr %[out1],%[in1],%[in2],0xD":[out1]"=r"(gray)
                                                            :[in1]"r"(valueA),
                                                             [in2]"r"(valueB));
        grayscale[line*camParams.nrOfPixelsPerLine+pixel  ] =  gray >> 24;
        grayscale[line*camParams.nrOfPixelsPerLine+pixel+1] = (gray >> 16) & 0xFF;
        grayscale[line*camParams.nrOfPixelsPerLine+pixel+2] = (gray >>  8) & 0xFF;
        grayscale[line*camParams.nrOfPixelsPerLine+pixel+3] =  gray        & 0xFF;
      }
    }
    asm volatile ("l.nios_rrr %[out1],r0,%[in2],0xC":[out1]"=r"(cycles):[in2]"r"(1<<8|7<<4));
    asm volatile ("l.nios_rrr %[out1],%[in1],%[in2],0xC":[out1]"=r"(stall):[in1]"r"(1),[in2]"r"(1<<9));
    asm volatile ("l.nios_rrr %[out1],%[in1],%[in2],0xC":[out1]"=r"(idle):[in1]"r"(2),[in2]"r"(1<<10));
    printf("nrOfCycles: %d %d %d\n", cycles, stall, idle);
  }
}
