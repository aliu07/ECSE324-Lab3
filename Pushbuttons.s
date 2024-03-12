.global _start
.equ PB_ADDR, 0xff200050

_start:
	
// This subroutine returns the indices of the pressed pushbuttons 
// (the keys from the pushbuttons Data register). The indices are 
// encoded based on a one-hot encoding scheme.
// - PB0 = 0x00000001
// - PB1 = 0x00000002
// - PB2 = 0x00000004
// - PB3 = 0x00000008
read_PB_data_ASM:
	LDR A1, =PB_ADDR // Load base address
	LDR A2, [A1] // Load contents of push buttons into A2
	MOV A1, A2 // Move value into A1 to return
	BX LR

// This subroutine receives a pushbutton index as an argument in A1. 
// Then, it returns 0x00000001 if the corresponding pushbutton is pressed.
PB_data_is_pressed_ASM:
	LDR A2, =PB_ADDR // Load base address
	LDR A3, [A2] // Load contents of push buttons
	AND A3, A3, A1 // Bitwise AND
	CMP A3, #0 // Check if the button at given index is pressed i.e. equal to 1
	