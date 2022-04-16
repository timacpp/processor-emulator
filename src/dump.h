#ifndef DUMP_H
#define DUMP_H

#include <stdio.h>
#include <inttypes.h>
#include <stdbool.h>

#define MEM_SIZE 256
#define WIDE_SKIP 7
#define NEW_LINE 15

typedef struct __attribute__((packed)) {
    uint8_t A, D, X, Y, PC;
    uint8_t unused; // Filler
    bool    C, Z;
} cpu_state_t;

static void dump_cpu_state(size_t core, cpu_state_t cpu_state, uint8_t const *data) {
    printf("core %zu: A = %02" PRIx8 ", D = %02" PRIx8 ", X = %02" PRIx8 ", Y = %02" PRIx8
    ", PC = %02" PRIx8 ", C = %hhu, Z = %hhu, [X] = %02" PRIx8 ", [Y] = %02" PRIx8
    ", [X + D] = %02" PRIx8 ", [Y + D] = %02" PRIx8 "\n",
            core, cpu_state.A, cpu_state.D, cpu_state.X, cpu_state.Y, cpu_state.PC,
            cpu_state.C, cpu_state.Z, data[cpu_state.X], data[cpu_state.Y],
            data[(cpu_state.X + cpu_state.D) & 0xFF],
            data[(cpu_state.Y + cpu_state.D) & 0xFF]);
}

static void dump_memory(uint8_t const *memory) {
    for (unsigned i = 0; i < MEM_SIZE; ++i) {
        printf("%02" PRIx8, memory[i]);
        unsigned r = i & 0xf;
        if (r == WIDE_SKIP)
            printf("  ");
        else if (r == NEW_LINE)
            printf("\n");
        else
            printf(" ");
    }
}

#endif // DUMP_H