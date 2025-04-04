    .syntax unified
    .cpu cortex-m4 
    .fpu softvfp
    .thumb
    
    .global random_delay
    .global rng

    .section .text


@
@ random_delay subroutine
@
@ Generate a random number of milliseconds to be 
@ used by the SysTick timer
@
@ Parameters:
@   None
@
@ Returns:
@   R0: delay - number of milliseconds (max 6000ms)
@
random_delay:                           @ int random_delay()
    PUSH        {R4, R5, LR}            @ {
    BL          rng                     @   int rand_num = rng(seed);
    MOV         R4, R0                  @
    AND         R4, R4, #0x7            @   rand_num &= 0x7;
    ADD         R4, R4, #2              @   rand_num += 2;
    CMP         R4, #6                  @   if (rand_num > 6)
    BLS         .Lendif_1               @   {
    MOV         R4, #6                  @       random_num = 6;
.Lendif_1:                              @   }
    MOV         R5, #1000               @   int tmp = 1000;
    MUL         R4, R4, R5              @   random_num *= tmp;
    MOV         R0, R4                  @   return rand_num
    POP         {R4, R5, PC}            @ }

@
@ rng subroutine
@
@ ARM Assembly implementation of a linear
@ congruential generator (LCG)
@
@ Parameters:
@   None
@
@ Returns:
@   R0: n - random number
@
rng:                                    @ int rng()
    PUSH        {R4-R6, LR}             @ {
    LDR         R5, =.Lseed             @   int x = seed;
    LDR         R4, [R5]                @
    LDR         R5, =1664525            @   int multiplier = 1664525;
    MUL         R4, R4, R5              @   x *= a;
    LDR         R6, =1013904223         @   int c = 1013904223;
    ADD         R4, R4, R6              @   x += c;
    LDR         R5, =.Lseed             @   seed = x;
    STR         R4, [R5]                @
    MOV         R0, R4                  @   return x;
    POP         {R4-R6, PC}             @ } 

    .section    .data

.Lseed:                                 @ int seed = 123456789;
    .word       123456789

    .end