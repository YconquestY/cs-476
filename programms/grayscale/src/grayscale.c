#include <stdio.h>
#include <ov7670.h>
#include <swap.h>
#include <vga.h>

#define __WITH_CI

int main () {
  const uint32_t writeBit = 1 << 9;

  const uint32_t busStartAddrCfg = 1 << 10;
  const uint32_t memoryStartAddrCfg = 2 << 10;
  const uint32_t pingCiRamAddr = 0,
                 pongCiRamAddr = 256;
  const uint32_t rgb565BlockSize = 256,
                 grayscaleBlockSize = 128;
  const uint32_t blockSizeCfg = 3 << 10;
  const uint32_t burstSize = 255;
  const uint32_t burstSizeCfg = 4 << 10;
  const uint32_t statusControl = 5 << 10;
  uint32_t camStatus,
           screenStatus;
  //const uint8_t sevenSeg[10] = {0x3F,0x06,0x5B,0x4F,0x66,0x6D,0x7D,0x07,0x7F,0x6F};
  volatile uint16_t rgb565[640*480];
  volatile uint8_t grayscale[640*480];
  volatile uint32_t result, cycles,stall,idle;
  volatile unsigned int *vga = (unsigned int *) 0X50000020;
  //volatile unsigned int *gpio = (unsigned int *) 0x40000000;
  camParameters camParams;
  vga_clear();
  // Reset memory
  printf("Clearing Ci-memory.\n");
  for (uint32_t ramAddr = 0; ramAddr < 512; ramAddr++) {
    asm volatile("l.nios_rrr r0,%[in1],r0,20" ::[in1] "r"(ramAddr | writeBit));
  }
  
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
  //uint32_t grayPixels;
  vga[2] = swap_u32(2);
  vga[3] = swap_u32((uint32_t) &grayscale[0]);

  uint32_t rgb565Pixels12, // TODO: endianess
           rgb565Pixels34;
  uint32_t grayscalePixels1234;
  while(1) {
    //uint32_t* rgb565Ptr    = (uint32_t*) &rgb565[0];
    //uint32_t* grayscalePtr = (uint32_t*) &grayscale[0];

    uint32_t val;

    takeSingleImageBlocking((uint32_t) &rgb565[0]);
/*
    asm volatile ("l.nios_rrr r0,r0,%[in2],0xC"::[in2]"r"(7));
    uint32_t dipswitch = swap_u32(gpio[0])^0xFF;
    uint32_t hunderds = dipswitch/100;
    uint32_t tens = (dipswitch%100)/10;
    uint32_t ones = dipswitch%10;
    gpio[0] = swap_u32((sevenSeg[hunderds] << 16) | (sevenSeg[tens] << 8) | sevenSeg[ones]);
*/

    // Iteration 0
/*
    for (uint32_t i = 0; i < 256; i++) {
      printf("%03d target: %08x\t%04x%04x\n", i, rgb565Ptr[i], rgb565[2*i], rgb565[2*i+1]);
    }
*/
    // DMA-transfer 512 RGB565 pixels from bus to Ci-memory
    asm volatile("l.nios_rrr r0,%[in1],%[in2],20" ::[in1] "r"(busStartAddrCfg | writeBit), // Write bus start address
                                                    [in2] "r"((uint32_t) &rgb565[0]));
    asm volatile("l.nios_rrr r0,%[in1],%[in2],20" ::[in1] "r"(memoryStartAddrCfg | writeBit), // Write Ci-memory start address
                                                    [in2] "r"(pingCiRamAddr));
    asm volatile("l.nios_rrr r0,%[in1],%[in2],20" ::[in1] "r"(blockSizeCfg | writeBit), // Write block size
                                                    [in2] "r"(rgb565BlockSize));
    asm volatile("l.nios_rrr r0,%[in1],%[in2],20" ::[in1] "r"(burstSizeCfg | writeBit), // Write burst size
                                                    [in2] "r"(burstSize));
    asm volatile("l.nios_rrr r0,%[in1],%[in2],20" ::[in1] "r"(statusControl | writeBit), // Start DMA transfer: from bus to Ci-memory
                                                    [in2] "r"(1));
    // Wait until DMA transfer done
    asm volatile("l.nios_rrr %[out1],%[in1],r0,20" :[out1]"=r"(camStatus) // Read status register
                                                   :[in1] "r"(statusControl));
    while (camStatus != 0) { // Poll status register until DMA controller is idle
      asm volatile("l.nios_rrr %[out1],%[in1],r0,20" :[out1]"=r"(camStatus)
                                                     :[in1] "r"(statusControl));
    }
/*
    uint32_t target = rgb565Ptr[512 / 2 - 1];
    asm volatile("l.nios_rrr %[out1],%[in1],r0,20" :[out1]"=r"(val) // Read last buffer cell
                                                   :[in1] "r"((uint32_t) 255));
    while (val != target) {
      asm volatile("l.nios_rrr %[out1],%[in1],r0,20" :[out1]"=r"(val) // Read last buffer cell
                                                     :[in1] "r"((uint32_t) 255));
      printf("000 waiting for 512 pixels written, current: %x, target: %x\n", val, target);
    }
*/
/*
    for (uint32_t i = 0; i < 256; i++) {
      asm volatile("l.nios_rrr %[out1],%[in1],r0,20" :[out1]"=r"(val)
                                                     :[in1] "r"(i));
      printf("%03d current: %08x\n", i, val);
    }
*/
/*
    asm volatile("l.nios_rrr %[out1],%[in1],r0,20" :[out1]"=r"(val)
                                                   :[in1] "r"((uint32_t) 0));
    printf("Ci-memory[0] = %x", val);
*/
    //return -1;

    // Iteration 0 ~ 598
    
    for (uint32_t i = 0; i < 598; i++)
    { // DMA-transfer 512 RGB565 pixels to the other part
      asm volatile("l.nios_rrr r0,%[in1],%[in2],20" ::[in1]"r"(busStartAddrCfg | writeBit), // Write bus start address
                                                      [in2]"r"((uint32_t) &rgb565[(i+1) * 512]));
      asm volatile("l.nios_rrr r0,%[in1],%[in2],20" ::[in1]"r"(memoryStartAddrCfg | writeBit), // Write Ci-memory start address
                                                      [in2]"r"(i & ((uint32_t) 1) ? pingCiRamAddr
                                                                                  : pongCiRamAddr));
      asm volatile("l.nios_rrr r0,%[in1],%[in2],20" ::[in1]"r"(blockSizeCfg | writeBit), // Write block size
                                                      [in2]"r"(rgb565BlockSize));
      asm volatile("l.nios_rrr r0,%[in1],%[in2],20" ::[in1]"r"(burstSizeCfg | writeBit), // Write burst size
                                                      [in2]"r"(burstSize));
      asm volatile("l.nios_rrr r0,%[in1],%[in2],20" ::[in1]"r"(statusControl | writeBit), // Start DMA transfer: from bus to Ci-memory
                                                      [in2]"r"(1));
      // Overwrite this part with grayscale pixels
      uint32_t ciRamAddr;
      //uint32_t bufferEndAddr;
      for (uint32_t j = 0; j < 256; j = j + 2)
      { // Read 4 RGB565 pixels
        asm volatile("l.nios_rrr %[out1],%[in1],r0,20" :[out1]"=r"(rgb565Pixels12)
                                                       :[in1] "r"(i & ((uint32_t) 1) ? pongCiRamAddr + j
                                                                                     : pingCiRamAddr + j));
        asm volatile("l.nios_rrr %[out1],%[in1],r0,20" :[out1]"=r"(rgb565Pixels34)
                                                       :[in1] "r"(i & ((uint32_t) 1) ? pongCiRamAddr + j + 1
                                                                                     : pingCiRamAddr + j + 1));
        // Convert RGB565 pixels to grayscale ones
        asm volatile ("l.nios_rrr %[out1],%[in1],%[in2],0x9":[out1]"=r"(grayscalePixels1234)
                                                            :[in1] "r" (rgb565Pixels12),
                                                             [in2] "r" (rgb565Pixels34));
        // Write grayscale pixels back to Ci-memory
        ciRamAddr = i & ((uint32_t) 1) ? pongCiRamAddr + j / 2
                                       : pingCiRamAddr + j / 2;
        //printf("%03d writing 0xFFFFFFFF to Ci-memory #%03d\n", i, ciRamAddr);
        asm volatile("l.nios_rrr r0,%[in1],%[in2],20" ::[in1] "r"(ciRamAddr | writeBit),
                                                        [in2] "r"(grayscalePixels1234));
      }
/*
      // Verify GRAY pixels
      uint32_t tmp;
      for (uint32_t j = 0; j < 128; j++)
      {
        ciRamAddr = i & ((uint32_t) 1) ? pongCiRamAddr + j
                                       : pingCiRamAddr + j;
        asm volatile("l.nios_rrr %[out1],%[in1],r0,20" :[out1]"=r"(tmp)
                                                       :[in1] "r"(ciRamAddr));
        if (tmp != (uint32_t) 0x80808080) {
          printf("%03d Ci-memory #%03d write error: %x\n", i, ciRamAddr, tmp);
          return -1;
        }
      }
*/
      // Verify DMA transfer to the other part is done
      asm volatile("l.nios_rrr %[out1],%[in1],r0,20" :[out1]"=r"(camStatus) // Read status register
                                                     :[in1] "r"(statusControl));
      while (camStatus != 0) { // Poll status register until DMA controller is idle
        asm volatile("l.nios_rrr %[out1],%[in1],r0,20" :[out1]"=r"(camStatus)
                                                       :[in1] "r"(statusControl));
      }
/*
      bufferEndAddr = i & ((uint32_t) 1) ? (uint32_t) 255
                                         : (uint32_t) 511;
      asm volatile("l.nios_rrr %[out1],%[in1],r0,20" :[out1]"=r"(val) // Read last buffer cell
                                                     :[in1] "r"(bufferEndAddr));
      while (val != rgb565Ptr[512 / 2 * (i+1) - 1]) {
        asm volatile("l.nios_rrr %[out1],%[in1],r0,20" :[out1]"=r"(val) // Read last buffer cell
                                                       :[in1] "r"(bufferEndAddr));
        printf("%03d waiting for 512 pixels written to the other buffer\n", i + 1);
      }
*/
      // DMA-transfer 512 grayscale pixels to screen
      asm volatile("l.nios_rrr r0,%[in1],%[in2],20" ::[in1]"r"(busStartAddrCfg | writeBit), // Write bus start address
                                                      [in2]"r"((uint32_t) &grayscale[i * 512]));
      asm volatile("l.nios_rrr r0,%[in1],%[in2],20" ::[in1]"r"(memoryStartAddrCfg | writeBit), // Write Ci-memory start address
                                                      [in2]"r"(i & ((uint32_t) 1) ? pongCiRamAddr
                                                                                  : pingCiRamAddr));
      asm volatile("l.nios_rrr r0,%[in1],%[in2],20" ::[in1]"r"(blockSizeCfg | writeBit), // Write block size
                                                      [in2]"r"(grayscaleBlockSize));
      asm volatile("l.nios_rrr r0,%[in1],%[in2],20" ::[in1]"r"(burstSizeCfg | writeBit), // Write burst size
                                                      [in2]"r"(burstSize));
      asm volatile("l.nios_rrr r0,%[in1],%[in2],20" ::[in1]"r"(statusControl | writeBit), // Start DMA transfer: from Ci-memory to bus
                                                      [in2]"r"(2));
      // Wait until DMA transfer done
      asm volatile("l.nios_rrr %[out1],%[in1],r0,20" :[out1]"=r"(screenStatus) // Read status register
                                                     :[in1] "r"(statusControl));
      while (screenStatus != 0) { // Poll status register until DMA controller is idle
        asm volatile("l.nios_rrr %[out1],%[in1],r0,20" :[out1]"=r"(screenStatus)
                                                       :[in1] "r"(statusControl));
      }
/*
      while (grayscalePtr[512 / 4 * i - 1] != 0x80808080) {
        printf("%03d waiting for 512 pixels written to screen\n", i);
      }
*/
    }
    // iteration 599

    uint32_t ciRamAddr;
    // Overwrite this part with grayscale pixels
    for (uint32_t j = 0; j < 256; j = j + 2)
    { // Read 4 RGB565 pixels
      asm volatile("l.nios_rrr %[out1],%[in1],r0,20" :[out1]"=r"(rgb565Pixels12)
                                                     :[in1] "r"(pongCiRamAddr + j));
      asm volatile("l.nios_rrr %[out1],%[in1],r0,20" :[out1]"=r"(rgb565Pixels34)
                                                     :[in1] "r"(pongCiRamAddr + j + 1));
      // Convert RGB565 pixels to grayscale ones
      asm volatile ("l.nios_rrr %[out1],%[in1],%[in2],0x9":[out1]"=r"(grayscalePixels1234)
                                                          :[in1] "r" (rgb565Pixels12),
                                                           [in2] "r" (rgb565Pixels34));
      // Write grayscale pixels back to Ci-memory
      ciRamAddr = pongCiRamAddr + j / 2;
      asm volatile("l.nios_rrr r0,%[in1],%[in2],20" ::[in1] "r"(ciRamAddr | writeBit),
                                                      [in2] "r"(grayscalePixels1234));
    }
/*
    // Verify GRAY pixels
    uint32_t tmp;
    for (uint32_t j = 0; j < 128; j++)
    {
      ciRamAddr = pongCiRamAddr + j;
      asm volatile("l.nios_rrr %[out1],%[in1],r0,20" :[out1]"=r"(tmp)
                                                     :[in1] "r"(ciRamAddr));
      if (tmp != (uint32_t) 0x80808080) {
        printf("599 Ci-memory #%03d write error: %x\n", ciRamAddr, tmp);
        return -1;
      }
    }
*/
    // DMA-transfer 512 grayscale pixels to screen
    asm volatile("l.nios_rrr r0,%[in1],%[in2],20" ::[in1]"r"(busStartAddrCfg | writeBit), // Write bus start address
                                                    [in2]"r"((uint32_t) &grayscale[599 * 512]));
    asm volatile("l.nios_rrr r0,%[in1],%[in2],20" ::[in1]"r"(memoryStartAddrCfg | writeBit), // Write Ci-memory start address
                                                    [in2]"r"(pongCiRamAddr));
    asm volatile("l.nios_rrr r0,%[in1],%[in2],20" ::[in1]"r"(blockSizeCfg | writeBit), // Write block size
                                                    [in2]"r"(grayscaleBlockSize));
    asm volatile("l.nios_rrr r0,%[in1],%[in2],20" ::[in1]"r"(burstSizeCfg | writeBit), // Write burst size
                                                    [in2]"r"(burstSize));
    asm volatile("l.nios_rrr r0,%[in1],%[in2],20" ::[in1]"r"(statusControl | writeBit), // Start DMA transfer: from Ci-memory to bus
                                                    [in2]"r"(2));
    // Wait until DMA transfer done
    asm volatile("l.nios_rrr %[out1],%[in1],r0,20" :[out1]"=r"(screenStatus) // Read status register
                                                   :[in1] "r"(statusControl));
    while (screenStatus != 0) { // Poll status register until DMA controller is idle
      asm volatile("l.nios_rrr %[out1],%[in1],r0,20" :[out1]"=r"(screenStatus)
                                                     :[in1] "r"(statusControl));
    }
/*
#ifdef __WITH_CI
      uint32_t * rgb = (uint32_t *) &rgb565[0];
      uint32_t * gray = (uint32_t *) &grayscale[0];
      for (int pixel = 0; pixel < ((camParams.nrOfLinesPerImage*camParams.nrOfPixelsPerLine) >> 1); pixel +=2) {
        uint32_t pixel1 = rgb[pixel];
        uint32_t pixel2 = rgb[pixel+1];
        asm volatile ("l.nios_rrr %[out1],%[in1],%[in2],0x9":[out1]"=r"(grayPixels):[in1]"r"(pixel1),[in2]"r"(pixel2));
        uint32_t newGrayPixel = (grayPixels&0xFF) > dipswitch ? 0xFF : 0x00;
        newGrayPixel |= ((grayPixels >> 8)&0xFF) > dipswitch ? 0xFF00 : 0;
        newGrayPixel |= ((grayPixels >> 16)&0xFF) > dipswitch ? 0xFF0000 : 0;
        newGrayPixel |= ((grayPixels >> 24)&0xFF) > dipswitch ? 0xFF000000 : 0;
        gray[0] = newGrayPixel;
        gray++;
      }
#else
    for (int line = 0; line < camParams.nrOfLinesPerImage; line++) {
      for (int pixel = 0; pixel < camParams.nrOfPixelsPerLine; pixel++) {
        uint16_t rgb = swap_u16(rgb565[line*camParams.nrOfPixelsPerLine+pixel]);
        uint32_t red1 = ((rgb >> 11) & 0x1F) << 3;
        uint32_t green1 = ((rgb >> 5) & 0x3F) << 2;
        uint32_t blue1 = (rgb & 0x1F) << 3;
        uint32_t gray = ((red1*54+green1*183+blue1*19) >> 8)&0xFF;
        grayscale[line*camParams.nrOfPixelsPerLine+pixel] = gray;
      }
    }
#endif
*/
/*
    asm volatile ("l.nios_rrr %[out1],r0,%[in2],0xC":[out1]"=r"(cycles):[in2]"r"(1<<8|7<<4));
    asm volatile ("l.nios_rrr %[out1],%[in1],%[in2],0xC":[out1]"=r"(stall):[in1]"r"(1),[in2]"r"(1<<9));
    asm volatile ("l.nios_rrr %[out1],%[in1],%[in2],0xC":[out1]"=r"(idle):[in1]"r"(2),[in2]"r"(1<<10));
    printf("nrOfCycles: %d %d %d\n", cycles, stall, idle);
*/
  }
}
