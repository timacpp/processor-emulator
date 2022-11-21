# About the project

This is a x86 emulation of a simplified Intel 8060 processor, suporting multicore computations and memory addressing.

# Registers and memory
The emulated processor provides 4 general purpose registers `A, D, X, Y` and 3 special flags `PC, Z, C`. One can address memory in form of `[X], [Y], [X + D], [Y + D]`,
where letters correspond to values stored in registers.

# Instructions
The list of supported instructions is limited, but large enough to perform loops, optimized basic arithmetic and bit operations.
