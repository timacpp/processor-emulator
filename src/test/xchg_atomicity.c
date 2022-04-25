#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include <pthread.h>

#ifndef CORES
#define CORES 4
#endif

#define MEM_SIZE 256

typedef struct __attribute__((packed)) {
    uint8_t A, D, X, Y, PC;
    uint8_t unused; // Wypełniacz, aby struktura zajmowała 8 bajtów.
    bool    C, Z;
} cpu_state_t;

// Tak zadeklarowaną funkcję można wywoływać też dla procesora jednordzeniowego.
cpu_state_t so_emul(uint16_t const *code, uint8_t *data, size_t steps, size_t core);

static void dump_cpu_state(size_t core, cpu_state_t cpu_state, uint8_t const *data) {
    printf("core %zu: A = %02" PRIx8 ", D = %02" PRIx8 ", X = %02" PRIx8 ", Y = %02"
    PRIx8 ", PC = %02" PRIx8 ", C = %hhu, Z = %hhu, [X] = %02" PRIx8 ", [Y] = %02"
    PRIx8 ", [X + D] = %02" PRIx8 ", [Y + D] = %02" PRIx8 "\n",
            core, cpu_state.A, cpu_state.D, cpu_state.X, cpu_state.Y, cpu_state.PC,
            cpu_state.C, cpu_state.Z, data[cpu_state.X], data[cpu_state.Y],
            data[(cpu_state.X + cpu_state.D) & 0xFF], data[(cpu_state.Y + cpu_state.D) & 0xFF]);
}

static void dump_memory(uint8_t const *memory) {
    for (unsigned i = 0; i < MEM_SIZE; ++i) {
        printf("%02" PRIx8, memory[i]);
        unsigned r = i & 0xf;
        if (r == 7)
            printf("  ");
        else if (r == 15)
            printf("\n");
        else
            printf(" ");
    }
}

// Sprawdzamy czy XCHG działa atomowo.
// W przykładzie XCHG X, [X] powinno zadziałać jako X = 0, [5] = 5 (a nie X = 0, [0] = 5).
// Analogicznie XCHG [Y], Y.
static const uint16_t xchg_atomicity[MEM_SIZE] = {
        0x4000 + 0x100 * 2 + 5,             // MOVI X, 5
        0x0008 + 0x100 * 2 + 0x0800 * 4,    // XCHG X, [X]
        0x4000 + 0x100 * 3 + 10,            // MOVI Y, 10
        0x4000 + 0x100 * 5 + 6,             // MOVI [Y], 6
        0x0008 + 0x100 * 5 + 0x0800 * 3     // XCHG [Y], Y
};

static uint8_t data[MEM_SIZE];

static void single_core_simple_test(void) {
    dump_cpu_state(0, so_emul(xchg_atomicity, data, 5, 0), data);
    dump_memory(data);
}


int main() {
    single_core_simple_test();
}
