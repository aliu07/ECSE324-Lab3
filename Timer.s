.global _start

.equ TIMER_ADDR, 0xFFFEC600

_start:
	MOV A1, #2000000 // Instantiate load value for timer
	LDR A3, =TIM_ADDR // Load base addrress of timer
	LDR A2, [A3, #8] // Load control value of timer into A2
	ORR A2, A2, #0x0000000
	BL ARM_TIM_config_ASM

// This subroutine is used to configure the timer (ARM V9 timer has 200MHz freq)
// A1: Load value -> value timer will count down from
// A2: Configuration bits
ARM_TIM_config_ASM: 
	PUSH {LR}
	LDR A3, =TIMER_ADDR // Load base address of timer
	STR A1, [A3] // Store load value into timer
	STR A2, [A3, #8] // Store control value of timer (Base address + 8)
	POP {LR}
	BX LR

// This subroutine returns the “F” value (0x00000000 or 0x00000001) from 
// the ARM A9 private timer interrupt status register.
ARM_TIM_read_INT_ASM:
	PUSH {LR}
	LDR A2, =TIMER_ADDR // Load base address into A2
	LDR A1, [A2, #12] // Load control register value into A1
	AND A1, A1, #0x00000001 // Keep only F bit which is MSB
	POP {LR}
	BX LR

// This subroutine clears the “F” value in the ARM A9 private timer 
// interrupt status register. The F bit can be cleared to 0 by writing 
// a 0x00000001 to the interrupt status register.
ARM_TIM_clear_INT_ASM:
	PUSH {LR}
	LDR A2, =TIMER_ADDR // Load base address into A2
	MOV A1, #0 // Move 0 into A1 to clear interrupt bit F in timer
	STR A1, [A2] // Write value in memory
	POP {LR}
	BX LR
