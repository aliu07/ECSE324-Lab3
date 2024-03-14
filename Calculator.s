.global _start

// I/O device addresses
.equ HEX_ADDR, 0xFF200020
.equ SW_ADDR, 0xFF200040
.equ LED_ADDR, 0xFF200000
.equ PB_ADDR, 0xFF200050
.equ PB_IM_ADDR, 0xFF200058
.equ PB_CER_ADDR, 0xFF20005C

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
	MOV A1, #0x3f // Indices for HEX0-HEX5
	BL HEX_clear_ASM // Clear all HEX displays
	
	MOV V1, #0 // Instantiate result to be displayed r
	
	MOV A1, #0x1f // Indices for HEX0-HEX4
	LDR A3, =SEV_SEG_DEC_MAP // Load base address of 7-segment values
	MOV A4, #0 // We want to display 0 to the HEX displays
	LDR A2, [A3, A4, LSL #1] // Fetch 7-segment value for 0
	BL HEX_write_ASM // Display zeroes

poll_buttons:
	// Whatever is released first is executed first

poll_switches:
	BL read_slider_switches_ASM // Check which sliders are on
	BL write_LEDs_ASM // Write to corresponding LEDs
	B poll // Keep on polling





// === SWITCHES AND LEDs - DRIVERS ===

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





// === HEX DISPLAYS - DRIVERS ===

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
	
HEX_display_neg:
	MOV A1, #0x20 // Index of left-most HEX display
	MOV A2, #0x40 // 7-segment value for dash
	PUSH {LR}
	BL HEX_write_ASM // Write dash to the left-most HEX display
	POP {LR}
	BX LR

// Input -> A1, A2
// A1: HEX display indices (0x0 - 0x1f)
// A2: Value to display to HEX displays (0-9)
// Output -> A2 displayed to HEX displays specified in A1
HEX_write_ASM:
	PUSH {V1-V2}
	LDR V1, =HEX_ADDR // Load base address into A3
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





// === PUSH BUTTONS - DRIVERS ===

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
// the edgecapture register to clear it. (clear captureedge register 
// with 1 bits)
PB_clear_edgecp_ASM:
	LDR A1, =PB_CER_ADDR // Move base address of captureedge register into A2
	LDR A2, [A1] // Load contents into A2
	STR A2, [A1] // Write read content back into captureedge register

// This subroutine receives pushbutton indices as an argument in A1. Then, 
// it enables the interrupt function for the corresponding pushbuttons 
// by setting the interrupt mask bits to '1'.
enable_PB_INT_ASM:
	LDR A2, =PB_IM_ADDR // Load interruptmask register address into A2
	STR A1, [A2] // Write indices of interrupted buttons into memory
	BX LR

// This subroutine receives pushbutton indices as an argument in A1. Then, 
// it disables the interrupt function for the corresponding pushbuttons 
// by setting the interrupt mask bits to '0'.
disable_PB_INT_ASM:
	LDR A2, =PB_IM_ADDR // Load interruptmask register address into A2
	MOV A3, #0xffffffff // Move string of 1-bits into A3
	EOR A1, A1, A3 // Bitwise XOR to get complementary of input -> c XOR 1 = c'
	STR A1, [A2] // Store value