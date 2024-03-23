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
    CMP R5, #73           // Check if interrupt raiser ID is pushbuttons'
    BNE Timer_check       // If ID of interrupt raiser is not pushbuttons', check if it timer's
    BL KEY_ISR            // Store edgecapture register content into memory
    B EXIT_IRQ            // Exit IRQ

Timer_check:
    CMP R5, #29           // Check if interrupt raiser ID is timer's     
    BNE UNEXPECTED        // If ID is still not recognized, then go to unexpected
    BL ARM_TIM_ISR        // Branch to timer ISR
    B EXIT_IRQ            // Exit IRQ

UNEXPECTED:
    B UNEXPECTED        
    

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

.equ LED_ADDR, 0xFF200000    // LEDs address
.equ HEX_ADDR, 0xFF200020    // HEX displays address
.equ SW_ADDR, 0xFF200040     // Switches address
.equ PB_ADDR, 0xFF200050     // Pushbuttons address
.equ PB_IM_ADDR, 0xFF200058  // Pushbuttons' interruptmask register address
.equ PB_CER_ADDR, 0xFF20005C // Pushbuttons' captureedge register address
.equ TIMER_ADDR, 0xFFFEC600  // Private timer address
.equ CONST_10MIL, 0x989680   // 10,000,000 constant to use as load value in private timer

// LETTER_MAP holds 7 segment decoded values for A through J
LETTER_MAP: .byte 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71, 0x3D, 0x76, 0x30, 0x1E
            .space 2

// NUM_MAP holds 7 segment decoded values for 0 through 9
NUM_MAP: .byte 0x03F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x67
         .space 2

// Note: The elements in LETTER_MAP and NUM_MAP must be unique. This is due to how I update the displays by searching the
//       element displayed on the rightmost/leftmost HEX display within the two arrays to find the proper offset.

// CURR_ROTATION holds 7 segment decoded values of current rotation in display
// At start time, same as number map, but will change over time as we write different values to it...
CURR_ROTATION: .byte 0x03F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x67
               .space 2

// CURR_DIR stores the direction bit in memory -> 0 = shift left, 1 = shift right
CURR_DIR: .word 0x1

PB_int_flag: .word 0x0
tim_int_flag: .word 0x0

// By default, a pre-programmed sequence or message at least 10 characters long flows left to right, shifting one position 
// every 0.25 seconds of simulated time, and wrapping around from right to left. Six characters of the message must be 
// displayed at all times. Reminder: the emulator does not guarantee real-time performance, and emulating 0.25 s may take 
// more than 0.25 s.

// Push-buttons modify the direction and rate of flow of characters:
//      - PB3 pauses and resumes character movement 
//      - PB2 reverses direction of movement 
//      - PB1 makes movement faster
//      - PB0 makes movement slower

// LEDs display the speed of movement relative to min and max; when paused, all LEDs should be off. When at max speed, all 
// LEDs should be on. Implement at least five rates, including 1/0.25 s; choose the other rates at your discretion. Choose 
// the manner in which LEDs are used to display rates other than paused and max.

// Slider switches change the characters in the message. In a minimal implementation with 10 character sequences, each
// slider switch toggles between two characters in each position of the sequence. Alternatively, you may use the slider
// switches to encode selection from a wider variety or partial or complete sequences, implemented at your discretion. 
// Implement at least 10 sequences or possible changes to the sequence.

_start:
    // Theoretically, the 4 lines below are not needed, but keep JUST TO BE SAFE
    BL PB_clear_edgecp_ASM            // Clear edgecapture register to ensure no unwanted interrupts get thrown
    BL ARM_TIM_read_INT_ASM           // Read F bit -> returned in A1
    CMP A1, #1                        // Check if F = 1
    BLEQ ARM_TIM_clear_INT_ASM        // Clear F bit of timer

    // SETUP DISPLAYS
    LDR V1, =NUM_MAP                  // Load base address of num map into V1
    MOV A1, #0x1                      // Index for HEX0
    LDRB A2, [V1, #5]                 // Load 5 into A2
    BL HEX_write_ASM                  // Write 5 to HEX0
    MOV A1, #0x2                      // Index for HEX1
    LDRB A2, [V1, #4]                 // Load 4 into A2
    BL HEX_write_ASM                  // Write 4 to HEX1
    MOV A1, #0x4                      // Index for HEX2
    LDRB A2, [V1, #3]                 // Load 3 into A2
    BL HEX_write_ASM                  // Write 3 to HEX2
    MOV A1, #0x8                      // Index for HEX3
    LDRB A2, [V1, #2]                 // Load 2 into A2
    BL HEX_write_ASM                  // Write 2 to HEX3
    MOV A1, #0x10                     // Index for HEX4
    LDRB A2, [V1, #1]                 // Load 1 into A2
    BL HEX_write_ASM                  // Write 1 to HEX4
    MOV A1, #0x20                     // Index for HEX5 
    LDRB A2, [V1]                     // Load 0 into A2
    BL HEX_write_ASM                  // Write 0 to HEX5

    // SETUP LEDs - 3/5th lit up at start up
    MOV A1, #0x3f // We want to light up 6 LEDs out of the 10 starting from the right
    BL write_LEDs_ASM

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
    BL enable_PB_INT_ASM
    // to enable interrupt for ARM A9 private timer, 
    // use ARM_TIM_config_ASM subroutine
    LDR A1, =CONST_10MIL // Move load value into A1 
    MOV A2, #0x7           // Set config bits -> I = 1, A = 1, E = 1
    MOV A3, #0x4           // Set prescaler bits to 4
    LSL A3, #8             // Shift up by 8
    ADD A2, A2, A3         // Concatenante prescaler and config bits into A2
    BL ARM_TIM_config_ASM  // Configure timer (10M load value w/ prescale = 4 -> 50MHz frequency at setup)


    LDR R0, =0xFF200050      // pushbutton KEY base address
    MOV R1, #0xF             // set interrupt mask bits
    STR R1, [R0, #0x8]       // interrupt mask register (base + 8)
    // enable IRQ interrupts in the processor
    MOV R0, #0b01010011      // IRQ unmasked, MODE = SVC
    MSR CPSR_c, R0

IDLE:
    // POLL SWITCHES
    BL check_switches     // Branch to update current rotation map
    // POLL PUSHBUTTONS
    LDR A1, =PB_int_flag  // Load address of pushbuttons interrupt flag
    LDR A2, [A1]          // Load flag into A2
    CMP A2, #0            // Check if flag is 0
    BEQ poll_timer        // Branch back to IDLE if so
    CMP A2, #0x1          // Check if button that was pressed & released is PB0
    BLEQ slow_down        // Branch to slow down subroutine if so
    CMP A2, #0x2          // Check if button that was pressed & released is PB1
    BLEQ speed_up         // Branch to speed up subroutine if so
    CMP A2, #0x4          // Check if button that was pressed & released is PB2
    BLEQ change_direction // Branch to change direction subroutine if so
    CMP A2, #0x8          // Check if button that was pressed & released is PB3
    BLEQ pause            // Branch to pause subroutine if so
    LDR A1, =PB_int_flag  // Load address of pushbuttons interrupt flag
    MOV A2, #0            // Move 0 to clear interrupt flag in memory
    STR A2, [A1]          // Store into memory
    
poll_timer:
    LDR A1, =tim_int_flag // Load address of timer interrupt flag
    LDR A2, [A1]          // Load flag into A2
    CMP A2, #0            // Check if flag is 0
    BEQ IDLE              // Branch back to IDLE if so
    LDR A1, =CURR_DIR     // Load base address of current direction variable
    LDR A2, [A1]          // Load contents of variable
    CMP A2, #0            // Check if variable is 0 or 1
    BLEQ shift_left       // Shift left if variable is 0
    BLNE shift_right      // Else shift right (var = 1)
    LDR A1, =tim_int_flag // Load address of timer interrupt flag
    MOV A2, #0            // Move 0 into A2 to clear flag in memory
    STR A2, [A1]          // Store into memory
    B IDLE                // Branch back to IDLE

check_switches:
    PUSH {A1-V4, LR}
    BL read_slider_switches_ASM // Get state of switches in A1
    MOV A2, #0                  // Instantiate index to 0

    check_switches_loop:
        CMP A2, #10             // Check if we have covered all the 10 buttons
        BEQ check_switche_end   // If so, then go back to IDLE state
        AND A3, A1, #1          // Move LSB into A3
        ASR A1, #1              // Shift button indices down by 1
        // UPDATE CURRENT ROTATION
        LDR A4, =CURR_ROTATION  // Load base address of current rotation of elements into A4
        LDRB V1, [A4, A2]       // Fetch elemnt at index i of current rotation
        AND V2, V1, #0x80       // Get bit 16 from the loaded elemnt -> 0 = number, 1 = letter
        ASR V2, #7              // Shift bit down 15 positions into LSB position
        CMP V2, A3              // Check if the bit is same as switch bit
        ADDEQ A2, A2, #1        // Increment index (setup for next iteration in case no work needs to be done)
        BEQ check_switches_loop // If they are equal, then no work needs to be done, go to next iteration
        CMP A3, #0              // Otherwise, check if switch is pressed (1) or not (0)
        LDREQ V3, =NUM_MAP      // Load number map address if 0
        LDRNE V3, =LETTER_MAP   // Otherwise, load letter map if 1
        LDRB V4, [V3, A2]       // Load element at index i from number map
        LSL A3, #7              // Move LSB up to bit 16
        ORR V4, V4, A3          // Append bit 16 to the rest of the 7-segment decoded value
        STRB V4, [A4, A2]       // Store the fetched element into current rotation map
        ADD A2, A2, #1          // Increment index
        B check_switches_loop   // Branch to next iteration

    check_switche_end:
        POP {A1-V4, PC}
    

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

    MOV R0, #29            // ID of timer
    MOV R1, #1             // Set CPU0 as the target for interrupts
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
    LDR R0, =0xFF200050    // Base address of pushbutton KEY port
    LDR R1, [R0, #0xC]     // Read edge capture register
    MOV R2, #0xF
    STR R2, [R0, #0xC]     // Clear the interrupt
    LDR R0, =PB_int_flag   // Load address of pushbutton interrupt flag
    STR R1, [R0]           // Store read edgecapture register content into memory
    BX LR

ARM_TIM_ISR:
    PUSH {LR}
    LDR A1, =tim_int_flag    // Load address of timer interrupt flag
    MOV A2, #1               // We want to write 1 to the timer interrupt flag in memory
    STR A2, [A1]             // Write value into memory
    BL ARM_TIM_clear_INT_ASM // Clear the interrupt
    POP {PC}

pause: // PB3
    PUSH {A1, LR}
    LDR A3, =TIMER_ADDR     // Load base address of timer into A3
    LDR A2, [A3, #8]        // Load content of prescaler bits and config bits into A2
    EOR A2, A2, #0x00000001 // Flip enable bit E (LSB)
    STR A2, [A3, #8]        // Store new config bits
    // CHANGE LEDS...
    AND A3, A2, #0x1        // Keep only E bit i.e. LSB
    CMP A3, #0              // Check if we are paused right now
    MOVEQ A1, #0x0          // If E = 0, then we want to shut off all LEDs
    BEQ pause_end           // Exit body
    ASR A3, A2, #8          // Shift down prescaler bits and store into A3
    AND A3, A3, #0xff       // Keep only 8 LSBs i.e. prescaler bits
    CMP A3, #1              // Check if prescale = 1
    MOVEQ A2, #0x3          // Upper bits
    LSLEQ A2, #8            // Shift up 8
    MOVEQ A1, #0xff         // Lower bits
    ADDEQ A1, A1, A2        // Light up 10 LEDs
    CMP A3, #2              // Check if prescale = 2
    MOVEQ A1, #0xff         // Light up 8 LEDs
    CMP A3, #4              // Check if prescale = 4
    MOVEQ A1, #0x3f         // Light up 6 LEDs
    CMP A3, #8              // Check if prescale = 8
    MOVEQ A1, #0xf          // Light up 4 LEDs
    CMP A3, #19             // Check if prescale = 19
    MOVEQ A1, #0x3          // Light up 2 LEDs 

    pause_end:
        BL write_LEDs_ASM   // Write value in A1 to LED memory
        POP {A1, PC}

change_direction: // PB2
    PUSH {LR}
    LDR A1, =CURR_DIR        // Load address of current direction value
    LDR A2, [A1]             // Load contents of current direction value
    EOR A2, A2, #0x00000001  // Flip the MSB current direction bit
    STR A2, [A1]             // Store the new direction value
    POP {PC}

speed_up: // PB1
    PUSH {V1-V2, LR}
    LDR A1, =TIMER_ADDR      // Move timer address into A1
    LDR A2, [A1, #8]         // Load contents of prescaler and config bits into A2
    AND A2, A2, #0x0000ff00  // Keep only prescaler bits
    ASR A2, #8               // Shift prescaler bits all the way down
    // Update speed
    CMP A2, #19              // Check if prescale = 19
    MOVEQ A2, #8             // If so, new prescale = 8
    BEQ speed_up_update_leds // And exit function
    CMP A2, #8               // Check if prescale = 8
    MOVEQ A2, #4             // If so, new prescale = 4
    BEQ speed_up_update_leds // And exit function
    CMP A2, #4               // Check if prescale = 4
    MOVEQ A2, #2             // If so, new prescale = 2
    BEQ speed_up_update_leds // And exit function
    CMP A2, #2               // Check if prescale = 2
    MOVEQ A2, #1             // If so, new prescale = 1
    // Ignore case prescale = 1 since 1 is fastest... no need to modify anything

    speed_up_update_leds:    // Update LEDs
        MOV V1, A2           // Move new prescale value into V1
        LSL A2, #8           // Shift up prescaler bits to right position
        LDR A3, [A1, #8]     // Load contents of prescaler and config bits into A3
        AND V2, A3, #0x1     // Keep only E bit in V2
        AND A3, A3, #0xf     // Keep only config bits in A3
        ORR A2, A2, A3       // Bitwise OR between A2 and A3 to concatenate prescaler and config bits
        STR A2, [A1, #8]     // Write new prescaler bits to memory
        CMP V2, #0           // Check if E = 0
        MOVEQ A1, #0         // Shut off all LEDs
        BEQ speed_up_end     // Branch to end
        CMP V1, #1           // Check if prescale = 1 -> MAX SPEED
        MOVEQ A2, #0x3       // Upper bits
        LSLEQ A2, #8         // Shift up 8
        MOVEQ A1, #0xff      // Lower bits
        ADDEQ A1, A1, A2     // Light up 10 LEDs (argument for write_LEDs_ASM)
        CMP V1, #2           // Check if prescale = 2
        MOVEQ A1, #0xff      // Light up 8 LEDs
        CMP V1, #4           // Check if prescale = 4
        MOVEQ A1, #0x3f      // Light up 6 LEDs
        CMP V1, #8           // Check if prescale = 8
        MOVEQ A1, #0xf       // Light up 4 LEDs
        CMP V1, #19          // Check if prescale = 19
        MOVEQ A1, #0x3       // Light up 2 LEDs

    speed_up_end: 
        BL write_LEDs_ASM    // Update LEDs
        POP {V1-V2, PC}

slow_down: // PB0
    PUSH {V1-V2, LR}
    LDR A1, =TIMER_ADDR       // Move timer address into A1
    LDR A2, [A1, #8]          // Load contents of prescaler and config bits into A2
    AND A2, A2, #0x0000ff00   // Keep only prescaler bits
    ASR A2, #8                // Shift prescaler bits all the way down
    // Update speed
    CMP A2, #1                // Check if prescale = 1
    MOVEQ A2, #2              // If so, new prescale = 2
    BEQ slow_down_update_leds // And exit function
    CMP A2, #2                // Check if prescale = 2
    MOVEQ A2, #4              // If so, new prescale = 4
    BEQ slow_down_update_leds // And exit function
    CMP A2, #4                // Check if prescale = 4
    MOVEQ A2, #8              // If so, new prescale = 8
    BEQ slow_down_update_leds // And exit function
    CMP A2, #8                // Check if prescale = 8
    MOVEQ A2, #19             // If so, new prescale = 19
    // Ignore case prescale = 19 since 19 is slowest... no need to modify anything

    slow_down_update_leds:   // Update LEDs
        MOV V1, A2           // Move new prescale value into V1
        LSL A2, #8           // Shift up prescaler bits to right position
        LDR A3, [A1, #8]     // Load contents of prescaler and config bits into A3
        AND V2, A3, #0x1     // Keep only E bit in V2
        AND A3, A3, #0xf     // Keep only config bits
        ORR A2, A2, A3       // Bitwise OR between A2 and A3 to concatenate prescaler and config bits
        STR A2, [A1, #8]     // Write new prescaler bits to memory
        CMP V2, #0           // Check if E = 0
        MOVEQ A1, #0         // Shut off all LEDs
        BEQ slow_down_end    // Branch to end
        CMP V1, #1           // Check if prescale = 1 -> MAX SPEED
        MOVEQ A2, #0x3       // Upper bits
        LSLEQ A2, #8         // Shift up 8
        MOVEQ A1, #0xff      // Lower bits
        ADDEQ A1, A1, A2     // Light up 10 LEDs (argument for write_LEDs_ASM)
        CMP V1, #2           // Check if prescale = 2
        MOVEQ A1, #0xff      // Light up 8 LEDs
        CMP V1, #4           // Check if prescale = 4
        MOVEQ A1, #0x3f      // Light up 6 LEDs
        CMP V1, #8           // Check if prescale = 8
        MOVEQ A1, #0xf       // Light up 4 LEDs
        CMP V1, #19          // Check if prescale = 19
        MOVEQ A1, #0x3       // Light up 2 LEDs 
        
    slow_down_end:
        BL write_LEDs_ASM    // Update LEDs
        POP {V1-V2, PC}

shift_left:
	PUSH {V1-V4, LR}
    MOV A1, #0x20                 // We want to read HEX5
    BL HEX_read_ASM               // Load contents of HEX5 into A1
    AND A1, A1, #0x7f             // Ignore bit 8
    MOV A2, #0                    // Instantiate index to 0 -> We want to find index corresponding to contents in A1
    LDR V3, =LETTER_MAP           // Load letter map base address into V3
    LDR V4, =NUM_MAP              // Load num map base address into V4
    
    left_find_index_loop:         // With the element in A1, find which index it corresponds to in the defined number/letter maps
        CMP A2, #10               // Check if index = 10 -> This is our termination condition
        BEQ UNEXPECTED            // Branch to unexpected if so (this should never happen)
        LDRB A3, [V3, A2]         // Load element at index from letter map into A3
        CMP A1, A3                // Compare value read from HEX5 in A1 to loaded value from map in A3
        MOVEQ A1, A2              // If values are same, then move index into A1
        BEQ perform_shift_left    // Branch to perform left shift
        LDRB A3, [V4, A2]         // Load element at index from num map
        CMP A1, A3                // Compate value read from HEX5 in A1 to loaded value from map in A3
        MOVEQ A1, A2              // If values are the same, then move index into A1
        BEQ perform_shift_left    // Branch to perform left shift
        ADD A2, A2, #1            // Increment index by 1
        B left_find_index_loop    // Loop back

    perform_shift_left:
        MOV A4, #0x20             // We start with index of HEX5

    perform_shift_left_loop:
        CMP A4, #0                // Terminate after we have written to HEX0
        BEQ shift_left_end        // Branch to end section if so
        ADD A1, A1, #1            // Increment index by 1 to find next element to write to HEX5 -> index = i
        CMP A1, #10               // Check if index in A1 is 10
        MOVEQ A1, #0              // Move 0 if index was 10
        LDR V1, =CURR_ROTATION    // Load base address of current rotation array
        LDRB A2, [V1, A1]         // Load element at index i from current rotation
        AND A3, A2, #0x00000080   // Check bit 8 of the element
        CMP A3, #0                // Check if bit 8 is 0 or 1 -> if 0 then load from number map... if 1 then load from letter map
        LDREQ V2, =NUM_MAP        // Load number map if bit 8 is 0
        LDRNE V2, =LETTER_MAP     // Load letter map if bit 8 is 1
        LDRB A2, [V1, A1]         // Load element at index i from appropriate map into A2
        STRB A2, [V1, A1]         // Store the element into current rotation array at position i
        MOV V3, A1                // Temporarily move index into V3
        MOV A1, A4                // Move HEX index into A1
        BL HEX_write_ASM          // Write value in A2 to current HEX display
        MOV A1, V3                // Move index back into A1
        ASR A4, #1                // Shift down by 1 for index of next HEX display
        B perform_shift_left_loop // Branch to next iteration of loop

    shift_left_end:
        POP {V1-V4, PC}

shift_right:
    PUSH {V1-V4, LR}
    MOV A1, #0x01       // We want to read HEX0
    BL HEX_read_ASM     // Load contents of HEX0 into A1
    AND A1, A1, #0x7f   // Ignore bit 8
    MOV A2, #0          // Instantiate index to 0 -> We want to find index corresponding to contents in A1
    LDR V3, =LETTER_MAP // Load letter map base address into V3
    LDR V4, =NUM_MAP    // Load num map base address into V4

    right_find_index_loop:
        CMP A2, #10             // Check if index = 10 -> This is our termination condition
        BEQ UNEXPECTED          // Branch to unexpected if so (this should never happen)
        LDRB A3, [V3, A2]       // Load element at index from letter map into A3
        CMP A1, A3              // Compare value read from HEX5 in A1 to loaded value from map in A3
        MOVEQ A1, A2            // If values are same, then move index into A1
        BEQ perform_shift_right // Branch to perform right shift
        LDRB A3, [V4, A2]       // Load element at index from num map
        CMP A1, A3              // Compate value read from HEX5 in A1 to loaded value from map in A3
        MOVEQ A1, A2            // If values are the same, then move index into A1
        BEQ perform_shift_right // Branch to perform right shift
        ADD A2, A2, #1          // Increment index by 1
        B right_find_index_loop // Loop back

    perform_shift_right:
        MOV A4, #0x1            // We start with index of HEX0

    shift_right_loop:
        CMP A4, #0x40           // Terminate after we have written to HEX5
        BEQ shift_right_end     // Branch to end section if so
        SUB A1, A1, #1          // Decrement index by 1 to find next element to write to HEX5 -> index = i
        CMP A1, #-1             // Check if A1 is -1 -> adjust if so (special case)
        MOVEQ A1, #9            // Move 9 if index was -1
        LDR V1, =CURR_ROTATION  // Load base address of current rotation array
        LDRB A2, [V1, A1]       // Load element at index i from current rotation
        AND A3, A2, #0x00000080 // Check bit 8 of the element
        CMP A3, #0              // Check if bit 8 is 0 or 1 -> if 0 then load from number map... if 1 then load from letter map
        LDREQ V2, =NUM_MAP      // Load number map if bit 8 is 0
        LDRNE V2, =LETTER_MAP   // Load letter map if bit 8 is 1
        LDRB A2, [V1, A1]       // Load element at index i from appropriate map into A2
        STRB A2, [V1, A1]       // Store the element into current rotation array at position i
        MOV V3, A1              // Temporarily move index into V3
        MOV A1, A4              // Move HEX index into A1
        BL HEX_write_ASM        // Write value in A2 to current HEX display
        MOV A1, V3              // Move index back into A1
        LSL A4, #1              // Shift down by 1 for index of next HEX display
        B shift_right_loop      // Branch back to loop

    shift_right_end:
        POP {V1-V4, PC}

// === TIMER - DRIVERS ===

// This subroutine is used to configure the timer (ARM V9 timer has 200MHz freq)
// A1: Load value -> value timer will count down from
// A2: Configuration bits (
//		I = interrrupt as soon as count hits 0, 
//		A = if A is 1, then load value is automatically reloaded into timer... 
//			if A is 0, then timer simply stops after reaching 0, 
//		E = enable timer to count down
// )
ARM_TIM_config_ASM: 
	PUSH {LR}
	LDR A3, =TIMER_ADDR // Load base address of timer
	STR A1, [A3]        // Store load value into timer
	STR A2, [A3, #8]    // Store control value of timer (Base address + 8)
	POP {PC}

// This subroutine returns the “F” value (0x00000000 or 0x00000001) from 
// the ARM A9 private timer interrupt status register in A1.
ARM_TIM_read_INT_ASM:
	PUSH {LR}
	LDR A2, =TIMER_ADDR     // Load base address into A2
	LDR A1, [A2, #12]       // Load control register value into A1
	AND A1, A1, #0x00000001 // Keep only F bit which is LSB
	POP {PC}

// This subroutine clears the “F” value in the ARM A9 private timer 
// interrupt status register. The F bit can be cleared to 0 by writing 
// a 0x00000001 to the interrupt status register.
ARM_TIM_clear_INT_ASM:
	PUSH {LR}
	LDR A2, =TIMER_ADDR // Load base address into A2
	MOV A1, #1          // Move 1 into A1 to clear interrupt bit F in timer
	ADD A2, A2, #12     // Add 12 to get address of where F bit is stored
	STR A1, [A2]        // Write value in memory
	POP {PC}

// === SWITCHES - DRIVERS ===

// Slider Switches Driver
// returns the state of slider switches in A1
// post- A1: slide switch state
read_slider_switches_ASM:
	PUSH {LR}
	LDR A2, =SW_ADDR     // load the address of slider switch state
	LDR A1, [A2]         // read slider switch state 
	POP {PC}



// === HEX DISPLAYS - DRIVERS ===

// This subroutine writes a value to a HEX dislay
// A1: Contains one-hot index of the HEX display we want to write to
// A2: Contains the value we want to write to that display
HEX_write_ASM:
	PUSH {V1-V2, LR}
	LDR V1, =HEX_ADDR // Load base address into A3 (also the address of HEX0)
	CMP A1, #0x2      // Check if we have to write to HEX1
	ADDEQ V1, V1, #1  // Add 1 to base address to get address of HEX1
	CMP A1, #0x4      // Check if we have to write to HEX2
	ADDEQ V1, V1, #2  // Add 2 to base address to get address of HEX2
	CMP A1, #0x8      // Check if we have to write to HEX3
	ADDEQ V1, V1, #3  // Add 3 to base address to get address of HEX3
	CMP A1, #0x10     // Check if we have to write to HEX4
	ADDEQ V1, V1, #16 // Add 16 to base address to get address of HEX4
	CMP A1, #0x20     // Check if we have to write to HEX5
	ADDEQ V1, V1, #17 // Add 17 to base address to get address  of HEX5
	STRB A2, [V1]     // Store value in A2 into appropriate HEX display
	POP {V1-V2, PC}

// This subroutine reads a value from a HEX display given an index
// A1: Contains one-hot index of the HEX display we want to read from
// A1 will also contain the contents of the HEX display we read from when returning form the subroutine
HEX_read_ASM:
    PUSH {V1-V2, LR}
    LDR V1, =HEX_ADDR // Load base address into A3 (also the address of HEX0)
	CMP A1, #0x2      // Check if we have to read from HEX1
	ADDEQ V1, V1, #1  // Add 1 to base address to get address of HEX1
	CMP A1, #0x4      // Check if we have to read from HEX2
	ADDEQ V1, V1, #2  // Add 2 to base address to get address of HEX2
	CMP A1, #0x8      // Check if we have to read from HEX3
	ADDEQ V1, V1, #3  // Add 3 to base address to get address of HEX3
	CMP A1, #0x10     // Check if we have to read from HEX4
	ADDEQ V1, V1, #16 // Add 16 to base address to get address of HEX4
	CMP A1, #0x20     // Check if we have to read from HEX5
	ADDEQ V1, V1, #17 // Add 17 to base address to get address  of HEX5
	LDRB A1, [V1]     // Load value of HEX display into A1
    POP {V1-V2, PC}



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
	LDR A2, [A1]     // Load contents of push buttons into A2
	MOV A1, A2       // Move value into A1 to return
	POP {PC}
	
// This subroutine returns the indices of the pushbuttons that have 
// been pressed and then released (the edge bits from the pushbuttons’ 
// Edgecapture register).
read_PB_edgecp_ASM:
	PUSH {LR}
	LDR A1, =PB_CER_ADDR // Load base address of captureedge register
	LDR A2, [A1]         // Load contents into A2
	MOV A1, A2           // Move result into A1 to return
	POP {PC}
	
// This subroutine clears the pushbutton Edgecapture register. You can 
// read the edgecapture register and write what you just read back to 
// the edgecapture register to clear it. (clear captureedge register 
// with 1 bits)
PB_clear_edgecp_ASM:
	PUSH {LR}
	LDR A1, =PB_CER_ADDR // Move base address of captureedge register into A2
	LDR A2, [A1]         // Load contents into A2
	STR A2, [A1]         // Write read content back into captureedge register
	POP {PC}

// This subroutine receives pushbutton indices as an argument in A1. Then, 
// it enables the interrupt function for the corresponding pushbuttons 
// by setting the interrupt mask bits to '1'.
enable_PB_INT_ASM:
	PUSH {LR}
	LDR A2, =PB_IM_ADDR // Load interruptmask register address into A2
	MOV A3, #0x0000000f // Move string of 1-bits into A3
	EOR A1, A1, A3      // Bitwise XOR to get complementary of input -> c XOR 1 = c'
	STR A1, [A2]        // Store value
	POP {PC}



// === LEDs - DRIVERS ===

// writes the state of LEDs (On/Off) in A1 to the LEDs' control register
// pre-- A1: data to write to LED state
write_LEDs_ASM:
    PUSH {LR}
	LDR A2, =LED_ADDR    // load the address of the LEDs' state
	STR A1, [A2]         // update LED state with the contents of A1
	POP {PC}