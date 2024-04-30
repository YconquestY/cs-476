#include <stdio.h>
#include <ov7670.h>
#include <swap.h>
#include <vga.h>

int main()
{
    //volatile uint32_t memArray[512];
    //uint32_t busAddress = (uint32_t) &memArray[0];
    const uint32_t config  = 0x3DC, // write to address 476
                   address = 476,
                   content = 0x12345678;

    uint32_t response;
    asm volatile ("l.nios_rrr %[rd],%[ra],%[rb],0x34":[rd]"=r"(response):[ra]"r"(config),[rb]"r"(content)); // Ci: 52
    printf("write %x to address %d\nwrite response is %d\n", content, config & 0xFF, response);
    printf("\n");
    uint32_t result;
    asm volatile ("l.nios_rrr %[rd],%[ra],r0,0x34":[rd]"=r"(result):[ra]"r"(address)); // Ci: 52
    printf("read from address %d\nresult is %x\n", address, result);
}