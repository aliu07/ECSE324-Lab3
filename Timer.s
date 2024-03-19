.global _start

.equ TIM_ADDR, 0xFFFEC600

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
	
	POP {LR}
	BX LR

// This subroutine returns the “F” value (0x00000000 or 0x00000001) from 
// the ARM A9 private timer interrupt status register.
ARM_TIM_read_INT_ASM:

// This subroutine clears the “F” value in the ARM A9 private timer 
// interrupt status register. The F bit can be cleared to 0 by writing 
// a 0x00000001 to the interrupt status register.
ARM_TIM_clear_INT_ASM:
