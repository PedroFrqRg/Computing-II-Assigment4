# LINK TO TEAM VIDEO
# https://drive.google.com/file/d/1DrjhTupPZAkUUCNG-1IAQT449qx9L-SV/view?usp=sharing

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

  BL     GPIO_enable               @ GPIO_enable();
  BL     LED_init_output           @ LED_init_output();   
  BL     USER_button_config        @ USER_button_config();
                                   @
  BL     random_delay              @
  LDR    R4, =.Lcounter_1          @
  LDR    R5, =.Linitial_delay      @
  STR    R0, [R4]                  @   counter_1 = random_delay();
  STR    R0, [R5]                  @   initial_delay = counter_1;
                                   @
  BL     SysTick_config            @ SysTick_config(counter_1);
                                   @
  @ Infinte loop waiting for interrupts
.LIdle_Loop:                       @ while(1) {
  B     .LIdle_Loop                @ }
  
End_Main:
  POP   {R4-R5, PC}



@
@ SysTick interrupt handler (Turn on corresponding LEDs)
@
  .type  SysTick_Handler, %function
SysTick_Handler:                   @ void SysTick_Handler()
  PUSH  {R4, R5, LR}               @ {

  LDR    R4, =SYSTICK_CSR          @
  LDR    R5, =0x0                  @
  STR    R5, [R4]                  @   SYSTICK_CSR = 0x0; // Stop SysTick timer

  LDR    R4, =.Lcounter_2          @
  LDR    R5, [R4]                  @   
  ADD    R5, R5, #1                @   counter_2 += 1;
  STR    R5, [R4]                  @   

  LDR     R4, =.Lcounter_1         @
  LDR     R5, [R4]                 @   
  CMP     R5, #0                   @   if (elapsed_time != 0)
  BEQ     .Ldisplay_LED            @   {
  SUB     R5, R5, #1               @     elapsed_time--;
  STR     R5, [R4]                 @
  B       .Lexit                   @   }
.Ldisplay_LED:                     @   else {
  LDR     R4, =GPIOE_ODR           @     // Turn on LD3
  LDR     R5, [R4]                 @
  ORR     R5, #(0b1<<(LD3_PIN))    @     GPIOE_ODR |= (1<<LD3_PIN);
  STR     R5, [R4]                 @ 
.Lexit:                            @   }

  LDR     R4, =SYSTICK_VAL         @   // Reset SysTick internal counter to 0
  LDR     R5, =0x1                 @   SYSTICK_VAL = 0x1;
  STR     R5, [R4]                 @

  LDR    R4, =SYSTICK_CSR          @
  LDR    R5, =0x7                  @   // Start SysTick timer by setting CSR to 0x7
  STR    R5, [R4]                  @   SYSTICK_CSR = 0x7; // Start SysTick timer

  LDR     R4, =SCB_ICSR            @   // Clear (acknowledge) the interrupt
  LDR     R5, =SCB_ICSR_PENDSTCLR  @
  STR     R5, [R4]                 @
  @ Return from interrupt handler
  POP  {R4, R5, PC}                @ }

@
@ External interrupt line 0 interrupt handler
@   (count button presses)
@
  .type  EXTI0_IRQHandler, %function
EXTI0_IRQHandler:                  @ void EXTI0_IRQHandler()
  PUSH  {R4-R6, LR}                @ {

  LDR    R4, =SYSTICK_CSR          @
  LDR    R5, =0x0                  @   // Stop SysTick timer
  STR    R5, [R4]                  @   SYSTICK_CSR = 0x0; 

  LDR    R4, =.Lcounter_2          @
  LDR    R5, [R4]                  @
  LDR    R4, =.Linitial_delay      @
  LDR    R6, [R4]                  @
  SUB    R5, R5, R6                @   int elapsed_time = counter_2 - initial_delay;

  MOV   R0, R5
  BL    display_score              @   display_score(elapsed_time);

  LDR   R4, =EXTI_PR               @   // Clear (acknowledge) the interrupt
  MOV   R5, #(1<<0)                @
  STR   R5, [R4]                   @
  @ Return from interrupt handler
  POP  {R4-R6, PC}                 @ }

@
@ GPIO_enable subroutine
@ Enable GPIO Port E by enabling its clock
@ in the RCC_AHBENR register
@ (RCC AHB Peripheral Clock Enable Register)
@
@ Parameters:
@   None
@
@ Returns:
@   None
@
GPIO_enable:                                            @ void GPIO_enable()
  PUSH    {R4, R5, LR}                                  @ {
  LDR     R4, =RCC_AHBENR                               @
  LDR     R5, [R4]                                      @
  ORR     R5, R5, #(0b1 << (RCC_AHBENR_GPIOEEN_BIT))    @   RCC_AHBENR |= 0b1 << RCC_AHBENR_GPIOEEN_BIT;
  STR     R5, [R4]                                      @
  POP     {R4, R5, PC}                                  @ }

@
@ LED_init_output subroutine
@ Configure LD3, LD4, LD5, LD6, LD7, LD8, LD9, and LD10
@ as output by setting bits 27:26 of GPIOE_MODER to 01
@ (GPIO Port E Mode Register)
@
@ Parameters:
@   None
@
@ Returns:
@   None
@
LED_init_output:                                        @ void LED_init_output()
  PUSH    {R4, R5, LR}                                  @ {

  LDR     R4, =GPIOE_MODER
  LDR     R5, [R4]                                      @ Read ...
  BIC     R5, #(0b11<<(LD3_PIN*2))                      @ Modify ...
  ORR     R5, #(0b01<<(LD3_PIN*2))                      @ write 01 to bits 
  STR     R5, [R4]                                      @ Write 


  LDR     R5, [R4]                                      @ Read ...
  BIC     R5, #(0b11<<(LD4_PIN*2))                      @ Modify ...
  ORR     R5, #(0b01<<(LD4_PIN*2))                      @ write 01 to bits 
  STR     R5, [R4]                                      @ Write 

  LDR     R5, [R4]                                      @ Read ...
  BIC     R5, #(0b11<<(LD5_PIN*2))                      @ Modify ...
  ORR     R5, #(0b01<<(LD5_PIN*2))                      @ write 01 to bits 
  STR     R5, [R4]                                      @ Write 

  LDR     R5, [R4]                                      @ Read ...
  BIC     R5, #(0b11<<(LD6_PIN*2))                      @ Modify ...
  ORR     R5, #(0b01<<(LD6_PIN*2))                      @ write 01 to bits 
  STR     R5, [R4]                                      @ Write 

  LDR     R5, [R4]                                      @ Read ...
  BIC     R5, #(0b11<<(LD7_PIN*2))                      @ Modify ...
  ORR     R5, #(0b01<<(LD7_PIN*2))                      @ write 01 to bits 
  STR     R5, [R4]                                      @ Write 

  LDR     R5, [R4]                                      @ Read ...
  BIC     R5, #(0b11<<(LD8_PIN*2))                      @ Modify ...
  ORR     R5, #(0b01<<(LD8_PIN*2))                      @ write 01 to bits 
  STR     R5, [R4]                                      @ Write 

  LDR     R5, [R4]                                      @ Read ...
  BIC     R5, #(0b11<<(LD9_PIN*2))                      @ Modify ...
  ORR     R5, #(0b01<<(LD9_PIN*2))                      @ write 01 to bits 
  STR     R5, [R4]                                      @ Write

  LDR     R5, [R4]                                      @ Read ...
  BIC     R5, #(0b11<<(LD10_PIN*2))                     @ Modify ...
  ORR     R5, #(0b01<<(LD10_PIN*2))                     @ write 01 to bits 
  STR     R5, [R4]                                      @ Write 
  
  POP     {R4, R5, PC}                                  @ }


@
@ SysTick_config subroutine
@ Configure SysTick timer to generate an interrupt
@ every 1 millisecond
@
@ Parameters:
@   R0: delay - number of milliseconds (max 6000ms)
@
@ Returns:
@   None
@
SysTick_config:                                         @ void SysTick_config() 
  PUSH    {R4-R6, LR}                                   @ {
  MOV     R6, #7999                                     @   int tmp = 7999; // Assuming 8MHz clock
  LDR     R4, =SCB_ICSR                                 @   // Clear any pre-existing interrupts
  LDR     R5, =SCB_ICSR_PENDSTCLR                       @   SCB_ICSR = SCB_ICSR_PENDSTCLR;
  STR     R5, [R4]                                      @
  LDR     R4, =SYSTICK_CSR                              @   // Stop SysTick timer
  LDR     R5, =0                                        @   SYSTICK_CSR = 0;
  STR     R5, [R4]                                      @  
  LDR     R4, =SYSTICK_LOAD                             @   SYSTICK_LOAD = tmp;
  STR     R6, [R4]                                      @ 
  LDR     R4, =SYSTICK_VAL                              @   // Reset SysTick internal counter to 0
  LDR     R5, =0x1                                      @   SYSTICK_VAL = 0x1;
  STR     R5, [R4]                                      @   
  LDR     R4, =SYSTICK_CSR                              @   // Start SysTick timer by setting CSR to 0x7
  LDR     R5, =0x7                                      @   SYSTICK_CSR = 0x7;
  STR     R5, [R4]                                      @
  POP     {R4-R6, PC}                                   @ }

@
@ USER_button_config subroutine
@ Configure the user button (EXTI0) to generate an interrupt
@ on falling edge
@
@ Parameters:
@   None
@
@ Returns:
@   None
@
USER_button_config:                                     @ void USER_button_config()
  PUSH    {R4, R5, LR}                                  @ {
  LDR     R4, =SYSCFG_EXTIICR1                          @   SYSCFG_EXTIICR1 &= ~(0xF);
  LDR     R5, [R4]                                      @
  BIC     R5, R5, #0b1111                             @
  STR     R5, [R4]                                      @                                                                
  LDR     R4, =EXTI_IMR                                 @   // Enable (unmask) interrupts on external interrupt Line0
  LDR     R5, [R4]                                      @   EXTI_IMR |= 1;
  ORR     R5, R5, #1                                    @
  STR     R5, [R4]                                      @  
  LDR     R4, =EXTI_FTSR                                @   // Set falling edge detection on Line0
  LDR     R5, [R4]                                      @   EXTI_FTSR |= 1;
  ORR     R5, R5, #1                                    @
  STR     R5, [R4]                                      @
  LDR     R4, =NVIC_ISER                                @   // Enable NVIC interrupt #6 (external interrupt Line0)
  MOV     R5, #(1<<6)                                   @   NVIC_ISER = 1<<6;
  STR     R5, [R4]                                      @
  POP     {R4, R5, PC}                                  @ }

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
    LDR         R5, =1000               @   int tmp = 1000;
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
@   R0: elapsed_time - time in milliseconds
@
@ Returns: 
@   None
@
display_score:                          @ void display_score(int elapsed_time)
    PUSH        {R4-R6, LR}             @ {
    MOV         R4, R0                  @
    LDR         R5, =GPIOE_ODR          @
                                        @
    CMP         R4, #300                @ switch(elapsed_time) {
    BLS         .Lcase_1                @
    CMP         R4, #400                @
    BLS         .Lcase_2                @
    CMP         R4, #500                @
    BLS         .Lcase_3                @
    CMP         R4, #600                @
    BLS         .Lcase_4                @
    CMP         R4, #700                @
    BLS         .Lcase_5                @
    CMP         R4, #800                @
    BLS         .Lcase_6                @
    CMP         R4, #900                @
    BLS         .Lcase_7                @
    CMP         R4, #1200               @
    BLS         .Lcase_8                @
    B           .Ldefault               @
.Lcase_1:                               @  case 100:    
    LDR     R6, [R5]                    @
    ORR     R6, #(0b1<<(LD3_PIN))       @     GPIOE_ODR |= (1<<LD3_PIN);
    STR     R6, [R5]                    @ 
.Lcase_2:                               @   case 150:
    LDR     R6, [R5]                    @
    ORR     R6, #(0b1<<(LD5_PIN))       @     GPIOE_ODR |= (1<<LD4_PIN);
    STR     R6, [R5]                    @ 
.Lcase_3:                               @   case 200：
    LDR     R6, [R5]                    @
    ORR     R6, #(0b1<<(LD7_PIN))       @     GPIOE_ODR |= (1<<LD7_PIN);
    STR     R6, [R5]                    @ 
.Lcase_4:                               @   case 250:
    LDR     R6, [R5]                    @
    ORR     R6, #(0b1<<(LD9_PIN))       @     GPIOE_ODR |= (1<<LD9_PIN);
    STR     R6, [R5]                    @ 
.Lcase_5:                               @   case 300:
    LDR     R6, [R5]                    @
    ORR     R6, #(0b1<<(LD10_PIN))      @     GPIOE_ODR |= (1<<LD10_PIN);
    STR     R6, [R5]                    @ 
.Lcase_6:                               @   case 350:
    LDR     R6, [R5]                    @
    ORR     R6, #(0b1<<(LD8_PIN))       @     GPIOE_ODR |= (1<<LD8_PIN);
    STR     R6, [R5]                    @ 
.Lcase_7:                               @   case 400:
    LDR     R6, [R5]                    @
    ORR     R6, #(0b1<<(LD6_PIN))       @     GPIOE_ODR |= (1<<LD6_PIN);
    STR     R6, [R5]                    @ 
.Lcase_8:                               @   case 450:
    LDR     R6, [R5]                    @
    ORR     R6, #(0b1<<(LD4_PIN))       @     GPIOE_ODR |= (1<<LD4_PIN);
    STR     R6, [R5]                    @ 
    B       .Lend_switch                @     break;
.Ldefault:                              @   default:
    LDR     R6, [R5]                    @
    ORR     R6, #(0b1<<(LD3_PIN))       @     GPIOE_ODR |= (1<<LD3_PIN);
    STR     R6, [R5]                    @ 
    LDR     R6, [R5]                    @
    ORR     R6, #(0b1<<(LD4_PIN))       @     GPIOE_ODR |= (1<<LD4_PIN);
    STR     R6, [R5]                    @ 
.Lend_switch:                           @   }
  POP         {R4-R6, LR}               @ }
  
  .section .data

.Lcounter_1:                            @ int counter_1 = 0;           
  .space  4                             @
.Lcounter_2:                            @ int counter_2 = 0;                
    .word 0                             @
.Linitial_delay:                        @ int initial_delay = 0;
    .space 4                            @
.Lseed:                                 @ int seed = 123456789;
    .word       12345678

.end
