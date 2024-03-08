# ECSE324-Lab3

# Emulator Link
https://ecse324.ece.mcgill.ca/simulator/?sys=arm-de1soc

# Switches & LEDs
Select the switches on the emulator interface. The associated LEDs will light up. An index is instantiated. On every even iteration, the LEDs associated to the switches light up. On every odd iteration, the complement LEDs light up.

# HEX Displays
The HEX_display contains 3 separate methods. 
**HEX_flood_ASM**: This method floods the selected HEX displays and lights up every segment.
**HEX_write_ASM**: This method floods the selected HEX displays with a specific value passed in register A2.
**HEX_clear_ASM**: This method clears the selected HEX displays. If any segments of the selected displays were on, they should go dark.
