# LINK TO TEAM VIDEO
# https://

  .syntax unified
  .cpu cortex-m4
  .fpu softvfp
  .thumb
  
  .global Main
  .global SysTick_Handler
  .global EXTI0_IRQHandler

  @ Definitions are in definitions.s to keep this file "clean"
  .include "definitions.s"

  .equ    BLINK_PERIOD, 250

  .section .text

Main:
  PUSH  {R4-R5, LR}

  BL     GPIO_enable
  BL     LED_init_output

  @ Configure SysTick Timer to generate an interrupt after delay
  BL     random_delay
  BL     SysTick_config

  @
  @ Prepare external interrupt Line 0 (USER pushbutton)
  @ We'll count the number of times the button is pressed
  @

  @ Initialise button_pressed flag to false
  LDR   R4, =button_pressed           @ button_pressed = false;
  MOV   R5, #0                        @
  STR   R5, [R4]                      @

  @ Configure USER pushbutton (GPIO Port A Pin 0 on STM32F3 Discovery
  @   kit) to use the EXTI0 external interrupt signal
  @ Determined by bits 3..0 of the External Interrrupt Control
  @   Register (EXTIICR)
  BL     USER_button_config

  @ Infinte loop waiting for interrupts
.LIdle_Loop:
  B     .LIdle_Loop
  
End_Main:
  POP   {R4-R5, PC}



@
@ SysTick interrupt handler (Turn on corresponding LEDs)
@
  .type  SysTick_Handler, %function
SysTick_Handler:

  PUSH  {R4, R5, LR}

  LDR     R4, =GPIOE_ODR            @   Turn on LD3
  LDR     R5, [R4]                  @
  ORR     R5, #(0b1<<(LD3_PIN))     @ GPIOE_ODR |= (1<<LD3_PIN);
  STR     R5, [R4]                  @ 

  LDR    R4, =SYSTICK_VAL
  MOV    R5, #0x1
  STR    R5, [R4]                  @   SYSTICK_VAL = 0x1; // Reset SysTick internal counter to 0

  LDR   R4, =button_pressed           @ button_pressed = false;
  MOV   R5, #0                        @
  STR   R5, [R4]                      @

  LDR     R4, =SCB_ICSR             @ Clear (acknowledge) the interrupt
  LDR     R5, =SCB_ICSR_PENDSTCLR   @
  STR     R5, [R4]                  @

  @ Return from interrupt handler
  POP  {R4, R5, PC}

@
@ External interrupt line 0 interrupt handler
@   (count button presses)
@
  .type  EXTI0_IRQHandler, %function
EXTI0_IRQHandler:

  PUSH  {R4-R6,LR}

  LDR   R4, =SYSTICK_VAL
  LDR   R5, [R4]                    @   SYSTICK_VAL = 0x1; // Reset SysTick internal counter to 0

  LDR   R4, =SYSTICK_LOAD           
  LDR   R6, [R4]

  SUB   R5, R6, R5                  @   clock_tics = SYSTICK_LOAD - SYSTICK_VAL;
  MOV   R4, #7999                   @   tmp = 7999;
  SDIV  R5, R5, R4                  @   elapsed_time = clock_tics / tmp;

  LDR   R4, =.Lelapsed_time         @   elapsed_time = clock_tics / tmp;
  STR   R5, [R4]                    @

  LDR   R4, =button_pressed         @ button_pressed = true;
  MOV   R5, #1                      @
  STR   R5, [R4]                    @

  LDR   R4, =EXTI_PR                @ Clear (acknowledge) the interrupt
  MOV   R5, #(1<<0)                 @
  STR   R5, [R4]                    @

  @ Return from interrupt handler
  POP  {R4-R6,PC}

@
@ GPIO_enable subroutine
@ Enable GPIO Port E by enabling its clock
GPIO_enable:                                            @ void GPIO_enable()
  PUSH    {R4, R5, LR}                                  @ {
  LDR     R4, =RCC_AHBENR                               @
  LDR     R5, [R4]                                      @
  ORR     R5, R5, #(0b1 << (RCC_AHBENR_GPIOEEN_BIT))    @   RCC_AHBENR |= 0b1 << RCC_AHBENR_GPIOEEN_BIT;
  STR     R5, [R4]                                      @
  POP     {R4, R5, PC}                                  @ }

LED_init_output:                                        @ void LED_init_output()
  PUSH    {R4, R5, LR}                                  @ {

  @ Configure LD3 for output
  @   by setting bits 27:26 of GPIOE_MODER to 01 (GPIO Port E Mode Register)
  @   (by BIClearing then ORRing)
  LDR     R4, =GPIOE_MODER
  LDR     R5, [R4]                    @ Read ...
  BIC     R5, #(0b11<<(LD3_PIN*2))    @ Modify ...
  ORR     R5, #(0b01<<(LD3_PIN*2))    @ write 01 to bits 
  STR     R5, [R4]                    @ Write 
  
  POP     {R4, R5, LR}                                  @ }


@
@ SysTick_config subroutine
@ Configure SysTick timer to generate an interrupt after
@ a specified number of milliseconds
@
@ Parameters:
@   R0: delay - number of milliseconds (max 6000ms)
@
@ Returns:
@   None
@
SysTick_config:                                                 @ void SysTick_config(int delay) 
  PUSH    {R4, R5, LR}                                          @ {
  MOV     R6, R0                                                @   
  LDR     R4, =SCB_ICSR                                         @   // Clear any pre-existing interrupts
  LDR     R5, =SCB_ICSR_PENDSTCLR                               @   SCB_ICSR = SCB_ICSR_PENDSTCLR;
  STR     R5, [R4]                                              @
  LDR     R4, =SYSTICK_CSR                                      @   // Stop SysTick timer
  LDR     R5, =0                                                @   SYSTICK_CSR = 0;
  STR     R5, [R4]                                              @  
  LDR     R4, =SYSTICK_LOAD                                     @   SYSTICK_LOAD = delay;
  STR     R6, [R4]                                              @ 
  LDR     R4, =SYSTICK_VAL                                      @   // Reset SysTick internal counter to 0
  LDR     R5, =0x1                                              @   SYSTICK_VAL = 0x1;
  STR     R5, [R4]                                              @   
  LDR     R4, =SYSTICK_CSR                                      @   // Start SysTick timer by setting CSR to 0x7
  LDR     R5, =0x7                                              @   SYSTICK_CSR = 0x7;
  STR     R5, [R4]                                              @
  POP     {R4, R5, LR}                                          @ }

USER_button_config:                                             @ void USER_button_config()
  PUSH    {R4, R5, LR}                                          @ {
  LDR     R4, =SYSCFG_EXTIICR1                                  @   SYSCFG_EXTIICR1 &= ~(0xF);
  LDR     R5, [R4]                                              @
  BIC     R5, R5, #0b1111                                     @ 
  STR     R5, [R4]                                              @                                                                
  LDR     R4, =EXTI_IMR                                         @   // Enable (unmask) interrupts on external interrupt Line0
  LDR     R5, [R4]                                              @   EXTI_IMR |= 1;
  ORR     R5, R5, #1                                            @
  STR     R5, [R4]                                              @  
  LDR     R4, =EXTI_FTSR                                        @   // Set falling edge detection on Line0
  LDR     R5, [R4]                                              @   EXTI_FTSR |= 1;
  ORR     R5, R5, #1                                            @
  STR     R5, [R4]                                              @
  LDR     R4, =NVIC_ISER                                        @   // Enable NVIC interrupt #6 (external interrupt Line0)
  MOV     R5, #(1<<6)                                           @   NVIC_ISER = 1<<6;
  STR     R5, [R4]                                              @
  POP     {R4, R5, LR}                                          @ }

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
    MOV         R5, #7999               @   int tmp = 1000;
    MUL         R4, R4, R5              @   random_num *= tmp;
    MOV         R0, R4                  @   return rand_num;
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
    MUL         R4, R4, R5              @   x *= multiplier;
    LDR         R6, =1013904223         @   int c = 1013904223;
    ADD         R4, R4, R6              @   x += c;
    LDR         R5, =.Lseed             @   seed = x;
    STR         R4, [R5]                @
    MOV         R0, R4                  @   return x;
    POP         {R4-R6, PC}             @ }

@
@ calculate_score
@
@ Calculate the score based on the elapsed time
@
@ Parameters:
@   None
@
@ Returns: 
@   R0: score - calculated score
@
calculate_score:
    PUSH        {R4, R5, LR}            @ {
    LDR         R4, =.Lelapsed_time     @   int elapsed_time = .Lelapsed_time;
    LDR         R4, [R4]                @
    
    CMP         R4, #100                @ switch(delay)
    BEQ         .Lcase_1                @
    CMP         R4, #150                
    BEQ         .Lcase_2
    CMP         R4, #200                
    BEQ         .Lcase_3
    CMP         R4, #250                
    BEQ         .Lcase_4
    CMP         R4, #300                
    BEQ         .Lcase_5
    CMP         R4, #350                
    BEQ         .Lcase_6  
    CMP         R4, #400                
    BEQ         .Lcase_7
    CMP         R4, #450                
    BEQ         .Lcase_8    



.Lcase_1:                               @  case 100:
    MOV         R5, #8                  @       score = 8;
    B           .LendSwitch             @       break;
.Lcase_2:                               @  case 150:
    MOV         R5, #7                  @       score = 7;
    B           .LendSwitch             @       break;
.Lcase_3:                               @  case 200：
    MOV         R5, #6                  @       score = 6;
    B           .LendSwitch             @       break;
.Lcase_4:                               @  case 250:
    MOV         R5, #5                  @       score = 5;
    B           .LendSwitch             @       break;
.Lcase_5:                               @  case 300:
    MOV         R5, #4                  @       score = 4;
    B           .LendSwitch             @       break;
.Lcase_6:                               @  case 350:
    MOV         R5, #3                  @       score = 3;
    B           .LendSwitch             @       break;
.Lcase_7:                               @  case 400:
    MOV         R5, #2                  @       score = 2;
    B           .LendSwitch             @       break;
.Lcase_8:                               @  case 450:
    MOV         R5, #1                  @       score = 1;

.LendSwitch:
    MOV         R0,R5
    POP         {R4, R5, LR}            @   int score = 0;


    

  .section .data
  
button_pressed:                         @ bool button_pressed;
  .space  4

.Lelapsed_time:                         @ int elapsed_time;           
  .space  4

.Lseed:                                 @ int seed = 123456789;
    .word       123456789

  .end
