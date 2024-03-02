.global _start
.equ BASE_HEX_ADDR, 0xFF200020

_start:
	MOV A1, #0x3f // Display indices to flood
	BL HEX_flood_ASM // Flood HEX displays
	MOV A1, #0x30 // New display indices
	MOV A2, #79 // Display value -> HEX encoding for 3
	BL HEX_write_ASM // Write value to specified indices
	MOV A1, #0x3f // Display indices to clear
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
	LDR A3, =BASE_HEX_ADDR // Load base address into A3
	MOV A4, #0 // Offset
	
writeLoop1:
	CMP A1, #0 // Check if any more indices left to flood
	BEQ writeEnd // If no more HEX displays left to flood, then break
	TST A1, #0x1 // Check if LSB is 1
	ASR A1, A1, #1 // Shift indices to the right to check next LSB
	BEQ writeLoop2 // If LSB is 0 then branch
	STRB A2, [A3, A4] // Set flood value to selected HEX display
	
// Logic to increment index
writeLoop2:
	CMP A4, #3 // Check if 4th iteration
	ADDNE A4, A4, #1 // Increment index normally
	ADDEQ A4, A4, #13 // Increment index to jump to 5th HEX display
	B writeLoop1 // Branch back to next iteration of loop
	
writeEnd:
	BX LR