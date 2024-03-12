.global _start
// Base address of push buttons
.equ PB_ADDR, 0xff200050
// Base address of captureedge register of push buttons
.equ PB_CER_ADDR, 0xFF20005C

_start:
	MOV A1, #0x1
	// BL PB_data_is_pressed_ASM
	BL PB_edgecp_is_pressed_ASM
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
	MOV A2, A1 // Move index argument into A2
	PUSH {A2, LR} // Push index value onto stack since subroutine might overwrite A2
	BL read_PB_data_ASM // Call method -> return value in A1
	POP {A2, LR} // Pop A2 off the stack
	AND A2, A2, A1 // Bitwise AND contents and given index
	CMP A2, #0 // Compare result to 0
	MOVGT A1, #1 // Return 1
	MOVLE A1, #0 // Return 0
	BX LR
	
// This subroutine returns the indices of the pushbuttons that have 
// been pressed and then released (the edge bits from the pushbuttons’ 
// Edgecapture register).
read_PB_edgecp_ASM:
	LDR A1, =PB_CER_ADDR // Load base address of captureedge register
	LDR A2, [A1] // Load contents into A2
	MOV A1, A2 // Move result into A1 to return
	BX LR

// This subroutine receives a pushbutton index as an argument in A1. 
// Then, it returns 0x00000001 if the corresponding pushbutton 
// has been pressed and released.
PB_edgecp_is_pressed_ASM:
	MOV A2, A1 // Move index into A2
	PUSH {A2, LR} // Push index and LR onto stack
	BL read_PB_edgecp_ASM // Call subroutine -> result returned in A1
	POP {A2, LR} // Pop A2 and LR off stack
	AND A2, A2, A1 // Bitwise AND given index and contents of edgecapture register
	CMP A2, #0 // Compare result of AND to 0
	MOVGT A1, #1 // Return 1
	MOVLE A1, #0 // Return 0
	BX LR
	
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