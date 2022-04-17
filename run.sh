#!/bin/bash

# Compile and link example C file and x86 assembly library
gcc -c -std=c17 -O2 -o main.o src/main.c
nasm -f elf64 -w+all -w+error -o emulator.o src/so_emulator.asm
gcc -o emulator emulator.o main.o

# Run executable
./emulator

# Remove temporary files
rm main.o
rm emulator.o
rm emulator