.section .vectors, "ax"
B _start            // reset vector
B SERVICE_UND       // undefined instruction vector
B SERVICE_SVC       // software interrupt vector
B SERVICE_ABT_INST  // aborted prefetch vector
B SERVICE_ABT_DATA  // aborted data vector
.word 0             // unused vector
B SERVICE_IRQ       // IRQ interrupt vector
B SERVICE_FIQ       // FIQ interrupt vector

/*--- Undefined instructions --------------------------------------*/
SERVICE_UND:
    B SERVICE_UND

/*--- Software interrupts ----------------------------------------*/
SERVICE_SVC:
    B SERVICE_SVC

/*--- Aborted data reads ------------------------------------------*/
SERVICE_ABT_DATA:
    B SERVICE_ABT_DATA

/*--- Aborted instruction fetch -----------------------------------*/
SERVICE_ABT_INST:
    B SERVICE_ABT_INST

/*--- IRQ ---------------------------------------------------------*/
SERVICE_IRQ:
    PUSH {R0-R7, LR}
    /* Read the ICCIAR from the CPU Interface */
    LDR R4, =0xFFFEC100
    LDR R5, [R4, #0x0C] // read from ICCIAR
    /* NOTE: Check which interrupt has occurred (check interrupt IDs)
   Then call the corresponding ISR
   If the ID is not recognized, branch to UNEXPECTED
   See the assembly example provided in the DE1-SoC Computer Manual
   on page 46 */

Pushbutton_check:
    CMP R5, #73

UNEXPECTED:
    BNE UNEXPECTED      // if not recognized, stop here
    BL KEY_ISR

EXIT_IRQ:
    /* Write to the End of Interrupt Register (ICCEOIR) */
    STR R5, [R4, #0x10] // write to ICCEOIR
    POP {R0-R7, LR}
    SUBS PC, LR, #4

/*--- FIQ ---------------------------------------------------------*/
SERVICE_FIQ:
    B SERVICE_FIQ









.text
.global _start

// By default, a pre-programmed sequence or message at least 10 characters long flows left to right, shifting one position 
// every 0.25 seconds of simulated time, and wrapping around from right to left. Six characters of the message must be 
// displayed at all times. Reminder: the emulator does not guarantee real-time performance, and emulating 0.25 s may take 
// more than 0.25 s.

// Push-buttons modify the direction and rate of flow of characters:
//      - PB3 pauses and resumes character movement, 
//      - PB2 reverses direction of movement, 
//      - PB1 makes movement faster, and
//      - PB0 makes movement slower.

// LEDs display the speed of movement relative to min and max; when paused, all LEDs should be off. When at max speed, all 
// LEDs should be on. Implement at least five rates, including 1/0.25 s; choose the other rates at your discretion. Choose 
// the manner in which LEDs are used to display rates other than paused and max.

// Slider switches change the characters in the message. In a minimal implementation with 10 character sequences, each
// slider switch toggles between two characters in each position of the sequence. Alternatively, you may use the slider
// switches to encode selection from a wider variety or partial or complete sequences, implemented at your discretion. 
// Implement at least 10 sequences or possible changes to the sequence.

_start:
    /* Set up stack pointers for IRQ and SVC processor modes */
    MOV R1, #0b11010010      // interrupts masked, MODE = IRQ
    MSR CPSR_c, R1           // change to IRQ mode
    LDR SP, =0xFFFFFFFF - 3  // set IRQ stack to A9 on-chip memory
    /* Change to SVC (supervisor) mode with interrupts disabled */
    MOV R1, #0b11010011      // interrupts masked, MODE = SVC
    MSR CPSR, R1             // change to supervisor mode
    LDR SP, =0x3FFFFFFF - 3  // set SVC stack to top of DDR3 memory
    BL  CONFIG_GIC           // configure the ARM GIC
    // NOTE: write to the pushbutton KEY interrupt mask register
    // Or, you can call enable_PB_INT_ASM subroutine from previous task
    // to enable interrupt for ARM A9 private timer, 
    // use ARM_TIM_config_ASM subroutine

    LDR R0, =0xFF200050      // pushbutton KEY base address
    MOV R1, #0xF             // set interrupt mask bits
    STR R1, [R0, #0x8]       // interrupt mask register (base + 8)
    // enable IRQ interrupts in the processor
    MOV R0, #0b01010011      // IRQ unmasked, MODE = SVC
    MSR CPSR_c, R0

IDLE:
    B IDLE // This is where you write your main program task(s)
	
CONFIG_GIC:
    PUSH {LR}
    /* To configure the FPGA KEYS interrupt (ID 73):
    * 1. set the target to cpu0 in the ICDIPTRn register
    * 2. enable the interrupt in the ICDISERn register */
    /* CONFIG_INTERRUPT (int_ID (R0), CPU_target (R1)); */
    /* NOTE: you can configure different interrupts
   by passing their IDs to R0 and repeating the next 3 lines */
    MOV R0, #73            // KEY port (Interrupt ID = 73)
    MOV R1, #1             // this field is a bit-mask; bit 0 targets cpu0
    BL CONFIG_INTERRUPT

    MOV R0, #29 // ID of timer
    MOV R1, #1 // Set CPU0 as the target for interrupts
    BL CONFIG_INTERRUPT

    /* configure the GIC CPU Interface */
    LDR R0, =0xFFFEC100    // base address of CPU Interface
    /* Set Interrupt Priority Mask Register (ICCPMR) */
    LDR R1, =0xFFFF        // enable interrupts of all priorities levels
    STR R1, [R0, #0x04]
    /* Set the enable bit in the CPU Interface Control Register (ICCICR).
    * This allows interrupts to be forwarded to the CPU(s) */
    MOV R1, #1
    STR R1, [R0]
    /* Set the enable bit in the Distributor Control Register (ICDDCR).
    * This enables forwarding of interrupts to the CPU Interface(s) */
    LDR R0, =0xFFFED000
    STR R1, [R0]
    POP {PC}
	
/*
* Configure registers in the GIC for an individual Interrupt ID
* We configure only the Interrupt Set Enable Registers (ICDISERn) and
* Interrupt Processor Target Registers (ICDIPTRn). The default (reset)
* values are used for other registers in the GIC
* Arguments: R0 = Interrupt ID, N
* R1 = CPU target
*/
CONFIG_INTERRUPT:
    PUSH {R4-R5, LR}
    /* Configure Interrupt Set-Enable Registers (ICDISERn).
    * reg_offset = (integer_div(N / 32) * 4
    * value = 1 << (N mod 32) */
    LSR R4, R0, #3    // calculate reg_offset
    BIC R4, R4, #3    // R4 = reg_offset
    LDR R2, =0xFFFED100
    ADD R4, R2, R4    // R4 = address of ICDISER
    AND R2, R0, #0x1F // N mod 32
    MOV R5, #1        // enable
    LSL R2, R5, R2    // R2 = value
    /* Using the register address in R4 and the value in R2 set the
    * correct bit in the GIC register */
    LDR R3, [R4]      // read current register value
    ORR R3, R3, R2    // set the enable bit
    STR R3, [R4]      // store the new register value
    /* Configure Interrupt Processor Targets Register (ICDIPTRn)
    * reg_offset = integer_div(N / 4) * 4
    * index = N mod 4 */
    BIC R4, R0, #3    // R4 = reg_offset
    LDR R2, =0xFFFED800
    ADD R4, R2, R4    // R4 = word address of ICDIPTR
    AND R2, R0, #0x3  // N mod 4
    ADD R4, R2, R4    // R4 = byte address in ICDIPTR
    /* Using register address in R4 and the value in R2 write to
    * (only) the appropriate byte */
    STRB R1, [R4]
    POP {R4-R5, PC}
	
KEY_ISR:
    LDR R0, =0xFF200050    // base address of pushbutton KEY port
    LDR R1, [R0, #0xC]     // read edge capture register
    MOV R2, #0xF
    STR R2, [R0, #0xC]     // clear the interrupt
    LDR R0, =0xFF200020    // base address of HEX display

CHECK_KEY0:
    MOV R3, #0x1
    ANDS R3, R3, R1        // check for KEY0
    BEQ CHECK_KEY1
    MOV R2, #0b00111111
    STR R2, [R0]           // display "0"
    B END_KEY_ISR

CHECK_KEY1:
    MOV R3, #0x2
    ANDS R3, R3, R1        // check for KEY1
    BEQ CHECK_KEY2
    MOV R2, #0b00000110
    STR R2, [R0]           // display "1"
    B END_KEY_ISR

CHECK_KEY2:
    MOV R3, #0x4
    ANDS R3, R3, R1        // check for KEY2
    BEQ IS_KEY3
    MOV R2, #0b01011011
    STR R2, [R0]           // display "2"
    B END_KEY_ISR

IS_KEY3:
    MOV R2, #0b01001111
    STR R2, [R0]           // display "3"

END_KEY_ISR:
    BX LR







// === SWITCHES - DRIVERS ===

// Slider Switches Driver
// returns the state of slider switches in A1
// post- A1: slide switch state
read_slider_switches_ASM:
	PUSH {LR}
	LDR A2, =SW_ADDR     // load the address of slider switch state
	LDR A1, [A2]         // read slider switch state 
	POP {LR}
	BX LR



// === HEX DISPLAYS - DRIVERS ===

// This subroutine writes a value to a HEX dislay
// A1: Contains one-hot index of the hex display we want to write to
// A2: Contains the value we want to write to that display
HEX_write_ASM:
	PUSH {V1-V2}
	LDR V1, =HEX_ADDR // Load base address into A3 (also the address of HEX0)
	CMP A1, #0x2 // Check if we have to write to HEX1
	ADDEQ V1, V1, #1 // Add 1 to base address to get address of HEX1
	CMP A1, #0x4 // Check if we have to write to HEX2
	ADDEQ V1, V1, #2 // Add 2 to base address to get address of HEX2
	CMP A1, #0x8 // Check if we have to write to HEX3
	ADDEQ V1, V1, #3 // Add 3 to base address to get address of HEX3
	CMP A1, #0x10 // Check if we have to write to HEX4
	ADDEQ V1, V1, #16 // Add 16 to base address to get address of HEX4
	CMP A1, #0x20 // Check if we have to write to HEX5
	ADDEQ V1, V1, #17 // Add 17 to base address to get address  of HEX5
	STRB A2, [V1] // Store value in A2 into appropriate HEX display
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
	POP {V1, LR}
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