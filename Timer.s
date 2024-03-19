.global _start

.equ TIMER_ADDR, 0xFFFEC600
.equ CONST_200MIL, 0xBEBC200 // Load value for the private timer -> 200M constant
.equ HEX_ADDR, 0xFF200020 // HEX displays

// Map holds 7 segment decoded values for 0 to F i.e. 0-15
SEV_SEG_DEC_MAP: .byte 0x03F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x67, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71

// HEX0 will display a value ranging between 0 and F. It will update the display every second using the integrated
// ARM V9 private timer which runs at a frequency of 200MHz. This is a very primitive way of integrating an interrupt
// service routine. We poll the interrupt bit F of the private timer and run the ISR block whenever an interrupt
// is detected.
_start:
	BL ARM_TIM_clear_INT_ASM
	LDR A1, =CONST_200MIL // Load constant to use as load value for timer
	MOV A2, #0x7 // Config bits -> I = 1, A = 1, E = 1
	BL ARM_TIM_config_ASM // Configure timer
	MOV A3, #0 // Instantiate index
	MOV A1, #0x1 // Index for HEX0
	LDR A4, =SEV_SEG_DEC_MAP // Load address of map into A4

poll_interrupt_bit:
	BL ARM_TIM_read_INT_ASM // Check F bit -> returned in A1
	CMP A1, #1 // Check if F = 1
	BEQ ISR // Do service routine if so
	B poll_interrupt_bit // Otherwise, keep on polling

ISR:
	BL ARM_TIM_clear_INT_ASM // Clear F bit
	CMP A3, #16 // If index = 15, then reset index
	MOVEQ A3, #0 // Reset index to 0
	LDRB A2, [A4, A3] // Load appropriate 7 segment value into A2
	BL HEX_write_ASM // Write value to HEX0
	ADD A3, A3, #1 // Increment index
	B poll_interrupt_bit

// This subroutine is used to configure the timer (ARM V9 timer has 200MHz freq)
// A1: Load value -> value timer will count down from
// A2: Configuration bits (
//		I = interrrupt as soon as count hits 0, 
//		A = if A is 1, then load value is automatically reloaded into timer... 
//			if A is 0, then timer simply stops after reaching 0, 
//		E = enable timer to count down
// )
ARM_TIM_config_ASM: 
	PUSH {LR}
	LDR A3, =TIMER_ADDR // Load base address of timer
	STR A1, [A3] // Store load value into timer
	STR A2, [A3, #8] // Store control value of timer (Base address + 8)
	POP {LR}
	BX LR

// This subroutine returns the “F” value (0x00000000 or 0x00000001) from 
// the ARM A9 private timer interrupt status register in A1.
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
	MOV A1, #1 // Move 1 into A1 to clear interrupt bit F in timer
	ADD A2, A2, #12 // Add 12 to get address of where F bit is stored
	STR A1, [A2] // Write value in memory
	POP {LR}
	BX LR





// === HEX DISPLAYS - DRIVERS ===

// This subroutine writes a value to a HEX dislay
// A1: Contains one-hot index of the hex display we want to write to
// A2: Contains the value we want to write to that display
HEX_write_ASM:
	PUSH {V1-V2}
	LDR V1, =HEX_ADDR // Load base address into A3 (also the address of HEX0)
	CMP A1, #0x2 // Check if we have to write to HEX1
	ADDEQ V1, V1, #1 // Add 1 to base address to get address of HEX1
	CMP A1, #0x4 // Check if we have to write to HEX2
	ADDEQ V1, V1, #2 // Add 2 to base address to get address of HEX2
	CMP A1, #0x8 // Check if we have to write to HEX3
	ADDEQ V1, V1, #3 // Add 3 to base address to get address of HEX3
	CMP A1, #0x10 // Check if we have to write to HEX4
	ADDEQ V1, V1, #16 // Add 16 to base address to get address of HEX4
	CMP A1, #0x20 // Check if we have to write to HEX5
	ADDEQ V1, V1, #17 // Add 17 to base address to get address  of HEX5
	STRB A2, [V1] // Store value in A2 into appropriate HEX display
	POP {V1-V2}
	BX LR