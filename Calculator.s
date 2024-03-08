.global _start
.equ BASE_HEX_ADDR, 0xFF200020
.equ BASE_SW_ADDR, 0xFF200040
.equ BASE_LED_ADDR, 0xFF200000

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
	