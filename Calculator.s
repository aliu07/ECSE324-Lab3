.global _start

// I/O device addresses
.equ HEX_ADDR, 0xFF200020
.equ SW_ADDR, 0xFF200040
.equ LED_ADDR, 0xFF200000

// Map holds 7 segment decoded values for 0 to 9
SEV_SEG_DEC_MAP: .word 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x67


// Calculator specifications...

// Switches SW0-SW3 correspond to the bits 0-3 of the first number (n) in binary. Switches SW4-SW7 correspond to the bits 0-3 of the second number (m) in binary

// Push buttons 0-3 correspond to the operations clear, multiplication, subtraction, and addition respectively. When the button is released, r is displayed

// In the case there is a result currently shown on the screen, you can add to, subtract from, or multiply that value if the clear button is not pressed.
// The calculator should display r op n in this case. m is ignored.

// The HEX displays should always show a value. At startup, r = 0 and the HEX displays show 00000. Clear resets r and the display to 00000 as well.

// In the case the result is negative, a negative sign should be shown next to the number. The leftmost HEX display is reserved for the sign.

// If r > 99999 / 0x0001869F or r < -99999 / 0xFFFE7961, the HEX displays should output OVRFLO until the clear operation is performed

_start:
	MOV V1, #0 // Instantiate r
	

// === DRIVERS ===

// Slider Switches Driver
// returns the state of slider switches in A1
// post- A1: slide switch state
read_slider_switches_ASM:
	LDR A2, =SW_ADDR     // load the address of slider switch state
	LDR A1, [A2]         // read slider switch state 
	BX LR
	
// LEDs Driver
// writes the state of LEDs (On/Off) in A1 to the LEDs' control register
// pre-- A1: data to write to LED state
write_LEDs_ASM:
	LDR A2, =LED_ADDR    // load the address of the LEDs' state
	STR A1, [A2]         // update LED state with the contents of A1
	BX LR

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
// value, 0-9, to display. These are passed in registers A1 
// and A2, respectively. Based on the second argument (A2), the 
// subroutine will display the corresponding hexadecimal digit 
// (0, 1, 2, 3, 4, 5, 6, 7, 8, 9) on the display(s).
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