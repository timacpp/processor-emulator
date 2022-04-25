#include <array>
#include <cassert>
#include <cinttypes>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <functional>
#include <iostream>
#include <random>
#include <set>
#include <vector>

constexpr size_t MEM_SIZE = 256;

typedef struct __attribute__((packed)) {
	uint8_t A, D, X, Y, PC;
	uint8_t unused; // Wypełniacz, aby struktura zajmowała 8 bajtów.
	bool C, Z;
} cpu_state_t;

extern "C" cpu_state_t so_emul(uint16_t const *code, uint8_t *data, size_t steps,
                               size_t core);

void dump_cpu_state(size_t core, cpu_state_t cpu_state, uint8_t const *data) {
	printf("core %zu: A = %02" PRIx8 ", D = %02" PRIx8 ", X = %02" PRIx8 ", Y = %02" PRIx8
	       ", PC = %02" PRIx8 ", C = %hhu, Z = %hhu, [X] = %02" PRIx8 ", [Y] = %02" PRIx8
	       ", [X + D] = %02" PRIx8 ", [Y + D] = %02" PRIx8 "\n",
	       core, cpu_state.A, cpu_state.D, cpu_state.X, cpu_state.Y, cpu_state.PC,
	       cpu_state.C, cpu_state.Z, data[cpu_state.X], data[cpu_state.Y],
	       data[(cpu_state.X + cpu_state.D) & 0xFF],
	       data[(cpu_state.Y + cpu_state.D) & 0xFF]);
}

void dump_memory(uint8_t const *memory) {
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

void dump_cpu_state(cpu_state_t cpu_state, const std::array<uint8_t, MEM_SIZE> &memory) {
	dump_cpu_state(0, cpu_state, memory.data());
}

void dump_memory(const std::array<uint8_t, MEM_SIZE> &memory) {
	dump_memory(memory.data());
}

auto so_emul(std::vector<uint16_t> code, size_t steps) {
	std::array<uint8_t, MEM_SIZE> memory;
	std::fill(memory.begin(), memory.end(), 0);
	assert(code.size() <= MEM_SIZE);
	std::array<uint16_t, MEM_SIZE> code_as_arr;
	std::fill(code_as_arr.begin(), code_as_arr.end(), 0);
	for (size_t i = 0; i < code.size(); ++i)
		code_as_arr[i] = code[i];
	cpu_state_t state = so_emul(code_as_arr.data(), memory.data(), steps, 0);
	return std::pair{state, memory};
}

void reset_register_states() {
	std::vector<uint16_t> code = {0x4000 + 0x100 * 0 + 0, // zerowanie ADXY
								  0x4000 + 0x100 * 1 + 0,
								  0x4000 + 0x100 * 2 + 0,
								  0x4000 + 0x100 * 3 + 0,

								  0x4000 + 0x100 * 0 + 1, // zerowanie CZ
								  0x0006 + 0x100 * 0 + 0x0800 * 1,
								  0x4000 + 0x100 * 0 + 0};

	// start kodu z PC = 0
	auto [state, _] = so_emul({}, 0);
	state = so_emul({}, 256 - state.PC).first;
	assert(state.PC == 0);
	state = so_emul(code, 256).first;
	assert(state.A == 0);
	assert(state.D == 0);
	assert(state.X == 0);
	assert(state.Y == 0);
	assert(state.PC == 0);
	assert(state.Z == 0);
	assert(state.C == 0);
}

void so_emul_print(std::vector<uint16_t> code, size_t steps) {
	auto [state, memory] = so_emul(code, steps);
	dump_cpu_state(state, memory);
	dump_memory(memory);
}

std::mt19937 rng(0);
int rd(int l, int r) {
	return rng() % (r - l + 1) + l;
}

int rd_small_or_big() {
	return rd(0, 1) ? rd(0, 3) : rd(0, 255);
}

std::array<std::function<int()>, 19> instruction_generators = {
    [] { return 0x0000 + 0x100 * rd(0, 7) + 0x0800 * rd(0, 7); },
    [] { return 0x0002 + 0x100 * rd(0, 7) + 0x0800 * rd(0, 7); },
    [] { return 0x0004 + 0x100 * rd(0, 7) + 0x0800 * rd(0, 7); },
    [] { return 0x0005 + 0x100 * rd(0, 7) + 0x0800 * rd(0, 7); },
    [] { return 0x0006 + 0x100 * rd(0, 7) + 0x0800 * rd(0, 7); },
    [] { return 0x0007 + 0x100 * rd(0, 7) + 0x0800 * rd(0, 7); },
    [] { return 0x4000 + 0x100 * rd(0, 7) + rd_small_or_big(); },
    [] { return 0x5800 + 0x100 * rd(0, 7) + rd_small_or_big(); },
    [] { return 0x6000 + 0x100 * rd(0, 7) + rd_small_or_big(); },
    [] { return 0x6800 + 0x100 * rd(0, 7) + rd_small_or_big(); },
    [] { return 0x7001 + 0x100 * rd(0, 7); },
    [] { return 0x8000; },
    [] { return 0x8100; },
    [] { return 0xC000 + rd_small_or_big(); },
    [] { return 0xC200 + rd_small_or_big(); },
    [] { return 0xC300 + rd_small_or_big(); },
    [] { return 0xC400 + rd_small_or_big(); },
    [] { return 0xC500 + rd_small_or_big(); },
    [] { return 0x0008 + 0x100 * rd(0, 7) + 0x0800 * rd(0, 7); },
    // [] { return 0xFFFF; }, // Tego Pana nie chcę w testach, bo powoduje on słabe testy.
};

int main() {
	constexpr size_t test_cnt = 10000;
	for (size_t test = 0; test < test_cnt; ++test) {
		rng.seed(test);
		printf("test=%ld:\n", test);

		const size_t instruction_count =
		    std::min(instruction_generators.size(),
		             3 + test / (test_cnt / instruction_generators.size()));
		const size_t steps = 1 + test;
		const size_t code_size =
		    std::min(MEM_SIZE, 5 + test / std::max(1ul, test_cnt / (256 - 8)));

		std::set<size_t> chosen_instruction_ids;
		while (chosen_instruction_ids.size() < instruction_count)
			chosen_instruction_ids.emplace(rd(0, instruction_generators.size() - 1));
		std::vector<std::function<size_t()>> chosen_instruction_generators;
		for (size_t i : chosen_instruction_ids)
			chosen_instruction_generators.emplace_back(instruction_generators[i]);

		std::vector<uint16_t> code;
		for (size_t i = 0; i < code_size; ++i) {
			std::function generator = chosen_instruction_generators[rd(
			    0, chosen_instruction_generators.size() - 1)];
			code.emplace_back(generator());
		}

		reset_register_states();
		so_emul_print(code, steps);
	}
}
