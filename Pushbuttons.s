.global _start
.equ PB_ADDR, 0xff200050

_start:
	MOV A1, #0x1
	BL PB_data_is_pressed_ASM
	B _end
	
_end:
	B _end
	
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
	BEQ return0 // If result of AND is 0, then branch to return 0
	
return1:
	MOV A1, #1 // Return 1
	BX LR
	
return0:
	MOV A1, #0 // Return 0
	BX LR
	
// This subroutine returns the indices of the pushbuttons that have 
// been pressed and then released (the edge bits from the pushbuttons’ 
// Edgecapture register).
read_PB_edgecp_ASM:

// This subroutine receives a pushbutton index as an argument. 
// Then, it returns 0x00000001 if the corresponding pushbutton 
// has been pressed and released.
PB_edgecp_is_pressed_ASM:
	
// This subroutine clears the pushbutton Edgecapture register. You can 
// read the edgecapture register and write what you just read back to 
// the edgecapture register to clear it.
PB_clear_edgecp_ASM:

// This subroutine receives pushbutton indices as an argument. Then, 
// it enables the interrupt function for the corresponding pushbuttons 
// by setting the interrupt mask bits to '1'.
enable_PB_INT_ASM:

// This subroutine receives pushbutton indices as an argument. Then, 
// it disables the interrupt function for the corresponding pushbuttons 
// by setting the interrupt mask bits to '0'.
disable_PB_INT_ASM: