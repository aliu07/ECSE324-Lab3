.global _start

_start:
	MOV A3, #0

evenLoop:
	AND A4, A3, #1
	CMP A4, #0
	BNE oddLoop
	BL read_slider_switches_ASM
	BL write_LEDs_ASM
	ADD A3, A3, #1
	B evenLoop

oddLoop:
	BL read_slider_switches_ASM
	MVN A1, A1
	BL write_LEDs_ASM
	ADD A3, A3, #1
	B evenLoop

// Slider Switches Driver
// returns the state of slider switches in A1
// post- A1: slide switch state
.equ SW_ADDR, 0xFF200040
read_slider_switches_ASM:
	LDR A2, =SW_ADDR     // load the address of slider switch state
	LDR A1, [A2]         // read slider switch state 
	BX LR

// LEDs Driver
// writes the state of LEDs (On/Off) in A1 to the LEDs' control register
// pre-- A1: data to write to LED state
.equ LED_ADDR, 0xFF200000
write_LEDs_ASM:
	LDR A2, =LED_ADDR    // load the address of the LEDs' state
	STR A1, [A2]         // update LED state with the contents of A1
	BX LR