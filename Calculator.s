.global _setup

// I/O device addresses
.equ HEX_ADDR, 0xFF200020 // HEX displays
.equ SW_ADDR, 0xFF200040 // Switches
.equ LED_ADDR, 0xFF200000 // LEDs
.equ PB_ADDR, 0xFF200050 // Pushbuttons
.equ PB_IM_ADDR, 0xFF200058 // Pushbuttons' interruptmask register
.equ PB_CER_ADDR, 0xFF20005C // Pushbuttons' captureedge register

// Map holds 7 segment decoded values for 0 to 9
SEV_SEG_DEC_MAP: .byte 0x03F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x67
				 .space 2

// Calculator specifications...

// Switches SW0-SW3 correspond to the bits 0-3 of the first number (n) in binary. Switches SW4-SW7 correspond to the bits 0-3 of the second number (m) in binary

// Push buttons 0-3 correspond to the operations clear, multiplication, subtraction, and addition respectively. When the button is released, r is displayed. Whatever is released first is executed first.

// In the case there is a result currently shown on the screen, you can add to, subtract from, or multiply that value if the clear button is not pressed.
// The calculator should display r op n in this case. m is ignored.

// The HEX displays should always show a value. At startup, r = 0 and the HEX displays show 00000. Clear resets r and the display to 00000 as well.

// In the case the result is negative, a negative sign should be shown next to the number. The leftmost HEX display is reserved for the sign.

// If r > 99999 / 0x0001869F or r < -99999 / 0xFFFE7961, the HEX displays should output OVRFLO until the clear operation is performed

// Setup
_setup:
	// TODO - Maybe will have to push V1
	MOV A1, #0x3f // Indices for HEX0-HEX5
	BL HEX_clear_ASM // Clear all HEX displays
	MOV A1, #0x1f // Indices for HEX0-HEX4
	LDR A3, =SEV_SEG_DEC_MAP // Load base address of 7-segment values
	MOV A4, #0 // We want to display 0 to the HEX displays
	LDRB A2, [A3, A4] // Fetch 7-segment value for 0
	BL HEX_write_ASM // Display zeroes to HEX displays

	MOV A4, #0 // Instantiate result variable r to A4 - DO NOT OVERWRITE

poll_buttons:
	// THIS POLLING METHOD ASSUMES PRIORITY HIERARCHY OF PB0 > PB1 > PB2 > PB3
	// PB0 HAS HIGHEST PRIO
	BL PB_clear_edgecp_ASM // Clear the edgecapture register
	BL read_PB_data_ASM // Load contents of PB into A1 -> Method returns value in A1
	TST A1, #0x1 // Check if PB0 (clear) has been pressed
	BGT handle_clear // Branch if clear button has been pressed
	TST A1, #0x2 // Check if PB1 (multiply) has been pressed
	BGT handle_multiplication // Branch if so
	TST A1, #0x4 // Check if PB2 (subtratction) has been pressed
	BGT handle_subtraction // Branch if so
	TST A1, #0x8 // Check if PB3 (addition) has been pressed
	BGT handle_addition // Branch if so
	B poll_buttons // Loop back to keep polling

handle_clear: // PB0 pressed
	MOV A1, #0xe // Disable indices PB1, PB2, PB3 -> 1110
	BL disable_PB_INT_ASM // Disable target pushbuttons
	MOV A1, #0x1 // Index for PB0
	BL PB_edgecp_is_pressed_ASM // Check if PB0 has been released
	CMP A1, #1 // check if return value is 1 i.e. if button has been pressed and released
	BEQ _setup // Branch back to setup
	B handle_clear // Keep polling until button is released

handle_multiplication: // PB1 pressed
	MOV A1, #0xd // Disable indices PB0, PB2, PB3 -> 1101
	BL disable_PB_INT_ASM // Disable target pushbuttons
	MOV A1, #0x2 // Index for PB1
	BL PB_edgecp_is_pressed_ASM // Check if PB1 has been released
	CMP A1, #1 // Check if return value is 1
	MOVEQ A1, #0x2 // TODO - CHANGE... Index of display to flood
	BEQ change_display // TODO - UPDATE TO REAL METHOD
	B handle_multiplication // Keep polling until button is released

do_multiplication:

handle_subtraction: // PB2 pressed
	MOV A1, #0xb // Disable indices PB0, PB1, PB3 -> 1011
	BL disable_PB_INT_ASM // Disable target pushbuttons
	MOV A1, #0x4 // Index for PB2
	BL PB_edgecp_is_pressed_ASM // Check if PB2 has been released
	CMP A1, #1 // Check if return value is 1
	MOVEQ A1, #0x4 // TODO - CHANGE... Index of display to flood
	BEQ change_display // TODO - UPDATE TO REAL METHOD
	B handle_subtraction // Keep polling until button is released

handle_addition: // PB3 pressed
	MOV A1, #0x7 // Disable indices PB0, PB1, PB2 -> 0111
	BL disable_PB_INT_ASM // Disable target pushbuttons
	MOV A1, #0x8 // Index for PB3
	BL PB_edgecp_is_pressed_ASM // Check if PB3 has been released
	CMP A1, #1 // Check if return value is 1
	BEQ do_addition // Branch to perform addition
	B handle_addition // Keep polling until button is released

do_addition:
	PUSH {V1-V2} // Use V1, V2 to store m, n values read from switches
	BL read_slider_switches_ASM // Load switches state into A1
	MOV V1, A1 // Move contents into V1 -> n
	AND V1, #0xf // Keep only 4 least significant bits
	MOV V2, A1 // Move contents into V2 -> m
	ASR V2, #4 // Remove 4 least significant bits
	AND V2, V2, #0xf // Keep 4 LSBs -> This instruction isn't necessary since MSBs are all 0 bits, but keep to be safe
	CMP A4, #0 // Check if r is 0
	MOVNE V2, A4 // If r != 0, override m stored in V2 with r -> we perform r op n
	ADD A4, V1, V2 // Perform addition and store result in A4
	BL update_display // Update HEX displays
	POP {V1-V2}
	B poll_buttons

// Updates display given a BCD value in A1
update_display:
	PUSH {LR}

	// CHECK OVERFLOW
	MOV A1, #0x9f // Lower 8 bits of binary representation of 99,999 (ImmVal can only go up to 256)
	MOV A2, #0x86 // Middle 8 bits
	LSL A2, #8 // Shift by 8
	MOV A3, #0x01 // Top 8 bits
	LSL A3, #16 // Shift by 16
	ADD A1, A1, A2 // Sum up A1 + A2 + A3
	ADD A1, A1, A3 // Sum up A1 + A2 + A3
	CMP A4, A1 // Check if result displayed r > 99999
	BGT overflow_state // Go to overflow state if so
	RSB A1, A1, #0 // Negate the value to get -99999
	CMP A4, A1 // Check if result displayed r < -99999 -- TODO: FIX
	BLT overflow_state // Go to overflor state if so

	// CHECK NEGATIVE SIGN
	CMP A4, #0 // Compare result displayed r to 0 to see if it is negative
	BLT HEX_display_neg // Display negative sign if so

	// FLOOD DISPLAYS
	

	POP {LR}
	BX LR

// Result to transform to bcd always in A4
hex_to_bcd:
	PUSH {LR}
	// ...
	POP {LR}
	BX LR

overflow_state:
	MOV A1, #0x20 // Index of HEX5
	MOV A2, #0x3F // "O"
	BL HEX_write_ASM
	MOV A1, #0x10 // Index of HEX4
	MOV A2, #0x3E // "V"
	BL HEX_write_ASM
	MOV A1, #0x8 // Index of HEX3
	MOV A2, #0x77 // "R"
	BL HEX_write_ASM
	MOV A1, #0x4 // Index of HEX2
	MOV A2, #0x71 // "F"
	BL HEX_write_ASM
	MOV A1, #0x2 // Index of HEX1
	MOV A2, #0x38 // "L"
	BL HEX_write_ASM
	MOV A1, #0x1 // Index of HEX0
	MOV A2, #0x3F // "O"
	BL HEX_write_ASM
	B handle_clear // Poll clear button



// === SWITCHES AND LEDs - DRIVERS ===

// Slider Switches Driver
// returns the state of slider switches in A1
// post- A1: slide switch state
read_slider_switches_ASM:
	PUSH {LR}
	LDR A2, =SW_ADDR     // load the address of slider switch state
	LDR A1, [A2]         // read slider switch state 
	POP {LR}
	BX LR
	
// LEDs Driver
// writes the state of LEDs (On/Off) in A1 to the LEDs' control register
// pre-- A1: data to write to LED state
write_LEDs_ASM:
	PUSH {LR}
	LDR A2, =LED_ADDR    // load the address of the LEDs' state
	STR A1, [A2]         // update LED state with the contents of A1
	POP {LR}
	BX LR





// === HEX DISPLAYS - DRIVERS ===

// This subroutine turns off all the segments of the selected 
// HEX displays. It receives the selected HEX display indices 
// through register A1 as an argument.
HEX_clear_ASM:
	PUSH {LR}
	MOV A2, #0x0 // Value to display is 0 for no segments on
	BL HEX_write_ASM // Call subroutine
	POP {LR}
	BX LR
	
// This subroutine turns on all the segments of the selected 
// HEX displays. It receives the selected HEX display indices 
// through register A1 as an argument.
HEX_flood_ASM:
	PUSH {LR}
	MOV A2, #0x7f // Value to display is 0x7f
	BL HEX_write_ASM // Call subroutine
	POP {LR}
	BX LR 
	
HEX_display_neg:
	PUSH {LR}
	MOV A1, #0x20 // Index of left-most HEX display
	MOV A2, #0x40 // 7-segment value for dash
	BL HEX_write_ASM // Write dash to the left-most HEX display
	POP {LR}
	BX LR

// Input -> A1, A2
// A1: HEX display indices (0x0 - 0x1f)
// A2: Value to display to HEX displays (0-9)
// Output -> A2 displayed to HEX displays specified in A1
HEX_write_ASM:
	PUSH {V1-V2, LR}
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
	POP {V1-V2, LR}
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
	PUSH {LR}
	LDR A1, =PB_ADDR // Load base address
	LDR A2, [A1] // Load contents of push buttons into A2
	MOV A1, A2 // Move value into A1 to return
	POP {LR}
	BX LR

// This subroutine receives a pushbutton index as an argument in A1. 
// Then, it returns 0x00000001 if the corresponding pushbutton is pressed.
PB_data_is_pressed_ASM:
	PUSH {V1, LR}
	MOV V1, A1 // Move index argument into A2
	BL read_PB_data_ASM // Call method -> return value in A1
	AND V1, V1, A1 // Bitwise AND contents and given index
	CMP V1, #0 // Compare result to 0
	MOVGT A1, #1 // Return 1
	MOVLE A1, #0 // Return 0
	POP {LR}
	BX LR
	
// This subroutine returns the indices of the pushbuttons that have 
// been pressed and then released (the edge bits from the pushbuttons’ 
// Edgecapture register).
read_PB_edgecp_ASM:
	PUSH {LR}
	LDR A1, =PB_CER_ADDR // Load base address of captureedge register
	LDR A2, [A1] // Load contents into A2
	MOV A1, A2 // Move result into A1 to return
	POP {LR}
	BX LR

// This subroutine receives a pushbutton index as an argument in A1. 
// Then, it returns 0x00000001 if the corresponding pushbutton 
// has been pressed and released.
PB_edgecp_is_pressed_ASM:
	PUSH {V1, LR}
	MOV V1, A1 // Move index into V1
	BL read_PB_edgecp_ASM // Call subroutine -> result returned in A1
	AND V1, V1, A1 // Bitwise AND given index and contents of edgecapture register
	CMP V1, #0 // Compare result of AND to 0
	MOVGT A1, #1 // Return 1
	MOVLE A1, #0 // Return 0
	POP {V1, LR}
	BX LR
	
// This subroutine clears the pushbutton Edgecapture register. You can 
// read the edgecapture register and write what you just read back to 
// the edgecapture register to clear it. (clear captureedge register 
// with 1 bits)
PB_clear_edgecp_ASM:
	PUSH {LR}
	LDR A1, =PB_CER_ADDR // Move base address of captureedge register into A2
	LDR A2, [A1] // Load contents into A2
	STR A2, [A1] // Write read content back into captureedge register
	POP {LR}
	BX LR

// This subroutine receives pushbutton indices as an argument in A1. Then, 
// it enables the interrupt function for the corresponding pushbuttons 
// by setting the interrupt mask bits to '1'.
enable_PB_INT_ASM:
	PUSH {LR}
	LDR A2, =PB_IM_ADDR // Load interruptmask register address into A2
	STR A1, [A2] // Write indices of interrupted buttons into memory
	POP {LR}
	BX LR

// This subroutine receives pushbutton indices as an argument in A1. Then, 
// it disables the interrupt function for the corresponding pushbuttons 
// by setting the interrupt mask bits to '0'.
disable_PB_INT_ASM:
	PUSH {LR}
	LDR A2, =PB_IM_ADDR // Load interruptmask register address into A2
	MOV A3, #0x0000000f // Move string of 1-bits into A3
	EOR A1, A1, A3 // Bitwise XOR to get complementary of input -> c XOR 1 = c'
	STR A1, [A2] // Store value
	POP {LR}
	BX LR