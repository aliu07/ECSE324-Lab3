# ECSE324-Lab3

# Emulator Link
https://ecse324.ece.mcgill.ca/simulator/?sys=arm-de1soc

# Switches & LEDs
The Switches_and_LEDs.s contains 2 separate methods.

**read_slider_switches_ASM**: Driver for swtiches - Returns the state of slider switches in register A1.

**write_LEDs_ASM**:  Driver for LEDs -  Writes the state of LEDs (On/Off) given switch indices in register A1 to the LEDs' control register

# HEX Displays
The HEX_display.s file contains 3 separate methods. 

**HEX_flood_ASM**: This method floods the selected HEX displays and lights up every segment.

**HEX_write_ASM**: This method floods the selected HEX displays with a specific value passed in register A2.

**HEX_clear_ASM**: This method clears the selected HEX displays. If any segments of the selected displays were on, they should go dark.

# Pushbuttons
The Pushbuttons.s contains 7 separate methods.

**read_PB_data_ASM**: This subroutine returns the indices of the pressed pushbuttons

**PB_data_is_pressed_ASM**: This subroutine receives a pushbutton index as an argument in A1. Then, it returns 0x00000001 if the corresponding pushbutton is pressed.

**read_PB_edgecp_ASM**: This subroutine returns the indices of the pushbuttons that have been pressed and then release (the edge bits from the pushbuttons' edgecapture register).

**PB_edgecp_is_pressed_ASM**: This subroutine receives a pushbutton index as an argument in A1. Then, it returns 0x00000001 if the corresponding pushbutton has been pressed and 
released.

**PB_clear_edgecp_ASM**: This subroutine clears the pushbuttons' edgecapture register by reading the value in the edgecapture register and then writing it back to it (clear the register with 1 bits).

**enable_PB_INT_ASM**: This subroutine receives pushbutton indices as an argument in register A1. Then, it enables the interrupt function for the corresponding pushbuttons by setting the interrupt mask bits to '1'.

**disable_PB_INT_ASM**: This subroutine receives pushbutton indices as an argument in register A1. Then, it disable the interrupt function for the correspnding pushbuttons by setting the interrupt mask bits to '0'.
