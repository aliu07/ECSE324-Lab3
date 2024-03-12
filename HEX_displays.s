.global _start
.equ BASE_HEX_ADDR, 0xFF200020
// Map holds 7 segment decoded values for 0 to 15
SEV_SEG_DEC_MAP: .word 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x67, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71

_start:
	MOV A1, #0x3F // Display indices to clear
	BL HEX_clear_ASM // Clear all displays
	MOV A1, #0x30 // Display indices to flood
	BL HEX_flood_ASM // Flood HEX displays
	MOV A1, #0x0f // New display indices
	LDR A3, =SEV_SEG_DEC_MAP // Load base address of array
	MOV A4, #6 // We want to display 2 to the HEX displays
	LDR A2, [A3, A4, LSL#2] // Display value
	BL HEX_write_ASM // Display indices to clear
	MOV A1, #0x0C // Display indices to clear (HEX 3 & 4)
	BL HEX_clear_ASM // Clear displays
	
end:
	B end

// This subroutine turns off all the segments of the selected 
// HEX displays. It receives the selected HEX display indices 
// through register A1 as an argument.
HEX_clear_ASM:
	MOV A2, #0x0 // Value to display is 0 for no segments on
	PUSH {LR} // Go back to _start after subroutine call
	BL HEX_write_ASM // Call subroutine
	POP {LR} // Restore link register
	BX LR // Branch back to _start



// This subroutine turns on all the segments of the selected 
// HEX displays. It receives the selected HEX display indices 
// through register A1 as an argument.
HEX_flood_ASM:
	MOV A2, #0x7f // Value to display is 0x7f
	PUSH {LR} // Go back to _start after subroutine call
	BL HEX_write_ASM // Call subroutine
	POP {LR} // Restore link register
	BX LR // Branch back to _start



// This subroutine receives HEX display indices and an integer 
// value, 0-15, to display. These are passed in registers A1 
// and A2, respectively. Based on the second argument (A2), the 
// subroutine will display the corresponding hexadecimal digit 
// (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, A, B, C, D, E, F) on the display(s).
HEX_write_ASM:
	PUSH {V1-V2}
	LDR V1, =BASE_HEX_ADDR // Load base address into A3
	MOV V2, #0 // Offset
	
writeLoop1:
	CMP A1, #0 // Check if any more indices left to flood
	BEQ writeEnd // If no more HEX displays left to flood, then break
	TST A1, #0x1 // Check if LSB is 1
	ASR A1, A1, #1 // Shift indices to the right to check next LSB
	BEQ writeLoop2 // If LSB is 0 then branch
	STRB A2, [V1, V2] // Set flood value to selected HEX display
	
// Logic to increment index
writeLoop2:
	CMP V2, #3 // Check if 4th iteration
	ADDNE V2, V2, #1 // Increment index normally
	ADDEQ V2, V2, #13 // Increment index to jump to 5th HEX display
	B writeLoop1 // Branch back to next iteration of loop
	
writeEnd:
	POP {V1-V2}
	BX LR