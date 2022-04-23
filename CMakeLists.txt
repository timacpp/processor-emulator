cmake_minimum_required(VERSION 3.22)
project(processor_emulator C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_FLAGS -pthread)

add_executable(example example/so_emulator_example.c src/dump.h)
