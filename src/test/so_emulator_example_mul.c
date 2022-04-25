#include <assert.h>
#include <inttypes.h>
#include <pthread.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef CORES
#define CORES 4
#endif

#define MEM_SIZE 256

typedef struct __attribute__((packed)) {
	uint8_t A, D, X, Y, PC;
	uint8_t unused; // Wypełniacz, aby struktura zajmowała 8 bajtów.
	bool C, Z;
} cpu_state_t;

// Tak zadeklarowaną funkcję można wywoływać też dla procesora jednordzeniowego.
cpu_state_t so_emul(uint16_t const *code, uint8_t *data, size_t steps, size_t core);

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
		if (r == 7)
			printf("  ");
		else if (r == 15)
			printf("\n");
		else
			printf(" ");
	}
}

// Mnoży wartości z komórek pamięci o adresach 0 i 1. Umieszcza wynik
// w komórkach pamięci o adresach 0 i 1 w porządku grubokońcówkowym.
// Bardzo podobnie wygląda mikrokod procesora 8086 realizujący mnożenie,
// patrz U.S. Patent No. 4,449,184.
static const uint16_t code_mul[MEM_SIZE] = {
    0x4000 + 0x100 * 2 + 1, // MOVI X, 1
    0x4000 + 0x100 * 3 + 0, // MOVI Y, 0
    0x0000 + 0x100 * 0 + 0x0800 * 5, // MOV  A, [Y]
    0x4000 + 0x100 * 5 + 0, // MOVI [Y], 0
    0x4000 + 0x100 * 1 + 8, // MOVI D, 8
    0x7001 + 0x100 * 4, // RCR  [X]
    0xC200 + 2, // JNC  +2
    0x8000, // CLC
    0x0006 + 0x100 * 5 + 0x0800 * 0, // ADC  [Y], A
    0x7001 + 0x100 * 5, // RCR  [Y]
    0x7001 + 0x100 * 4, // RCR  [X]
    0x6000 + 0x100 * 1 + 255, // ADDI D, -1
    0xC400 + (uint8_t) -7, // JNZ  -7
    0xC000 // MOV  A, A; czyli NOP
};

static uint8_t data[MEM_SIZE];

static void single_core_mul_test(uint8_t a, uint8_t b) {
	cpu_state_t cpu_state;

	data[0] = a;
	data[1] = b;
	dump_memory(data);

	// Kod można wykonywać krokowo.
	dump_cpu_state(0, cpu_state = so_emul(code_mul, data, 0, 0), data);
	while (cpu_state.PC != 13) {
		dump_cpu_state(0, cpu_state = so_emul(code_mul, data, 1, 0), data);
	}

	dump_memory(data);
}

int main() {
	single_core_mul_test(61, 18);
}
