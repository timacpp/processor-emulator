; Solution modifies rax, rsp, rdi, rsi, rbx, r8, r9, r10 registers and preserves rbx.

; For the matter of simplicity I use term nibble to describe a single hexadecimal digit:
; 0x[highest nibble][second highest nibble][second lowest nibble][lowest nibble]

; First, we introduce 5 instruction categories:
; A2 - requires 2 arguments;
; AI - requires 1 argument and 1 immediate value (in such order);
; A1 - requires *only* one argument;
; I1 - requires *only* one immediate value;
; A0 - requires no parameters;

; Highest nibble of an instruction encodes the category. Instruction type and
; parameters, if such exist, are encoded differently for each category (more below).

global so_emul

; Maximal value of the highest nibble of instructions within the category:
A2_HIMX equ 0x3
AI_HIMX equ 0x6

; Exact value of the highest nibble of instructions within the category:
A1_HIEX equ 0x7
I1_HIEX equ 0xC

; Lowest nibbles of each A2 instruction:
MOV_LO  equ 0x0
OR_LO   equ 0x2
ADD_LO  equ 0x4
SUB_LO  equ 0x5
ADC_LO  equ 0x6
SBB_LO  equ 0x7

; Second lowest nibbles of each A1 instruction:
RCR_2LO equ 0x0

; Maximal highest *byte* of each AI instruction:
MOVI_BY equ 0x47
XORI_BY equ 0x5F
ADDI_BY equ 0x67
CMPI_BY equ 0x6F

; Second highest nibbles of each A0 instruction:
CLC_2HI equ 0x0
STC_2HI equ 0x1
BRK_2HI equ 0xF

; Second highest nibbles of each I1 instruction:
JMP_2HI equ 0x0
JNC_2HI equ 0x2
JC_2HI  equ 0x3
JNZ_2HI equ 0x4
JZ_2HI  equ 0x5

; Indices of virtual registers and flags values located on stack
A_REG   equ 0
D_REG   equ 1
X_REG   equ 2
Y_REG   equ 3
PC_CNT  equ 4
C_FLAG  equ 6
Z_FLAG  equ 7

CPU_SZ  equ 8 ; Bytes required to store a CPU state

; Values referring to virtual memory and registers. Smaller entries (0-4)
; correspond to values of virtual registers (same order as in CPU state).
X_MEM   equ 4
Y_MEM   equ 5
XD_MEM  equ 6
YD_MEM  equ 7

NIB  equ 4 ; Size of nibble in bits

section .text

; Matches argument stored in 'bl' (0-7) with the value of a virtual
; register or an adressed memory. Result is written to 'al'.
; Registers modified: al, r8b, r9b, r10b.
match_argument:
; If argument is not greater than 3, then it referres to a register.
        cmp     bl, Y_REG
        ja      match_x_mem
        mov     al, byte [rsi + rbx * 2]
        ret
; Otherwise, we check though each value referring to an adressed memory.
match_x_mem:
        mov     r8b, byte [rsp + X_REG] ; Write value of register X
        cmp     bl, X_MEM
        jne     match_y_mem
        mov     al, byte [rsi + r8 * 2]
        ret
match_y_mem:
        mov     r9b, byte [rsp + Y_REG] ; Write value of register Y
        cmp     bl, Y_MEM
        jne     match_xd_mem
        mov     al, byte [rsi + r9 * 2]
        ret
match_xd_mem:
        mov     r10b, byte [rsp + D_REG] ; Write value of register D
        cmp     bl, XD_MEM
        jne     match_yd_mem
        add     r10b, r8b ; Now r10b holds value of X + D
        mov     al, byte [rsi + r10 * 2]
        ret
match_yd_mem:
        cmp     bl, YD_MEM
        jne     unmatched
        add     r10b, r9b ; Now r10b holds value of Y + D
        mov     al, byte [rsi + r10 * 2]
        ret
; Terminate program if argument did not match. For debugging purposes.
unmatched:
        jmp     build_state


so_emul: ; TODO: preserve state
        xor     rax, rax    ; TODO
        test    rdx, rdx    ; If program consists of 0 steps
        jz      end_program ; Leave CPU state unmodified and end program

        push    rbx              ; Preserve nonvolatile rbx register
        sub     rsp, CPU_SZ      ; Allocate 8 bytes on stack for CPU state
        mov     qword [rsp], 0   ; TODO

; Clear registers for storing temporary values
        xor     r8, r8
        xor     r9, r9
        xor     r10, r10
        xor     rbx, rbx

steps_loop:
        mov     r8b, byte [rsp + PC_CNT] ; Read index of the current instruction
        mov     ax, word [rdi + r8 * 2]  ; Read code of current instruction

; Split instruction code by nibbles without trailing zeroes: 0x[bh][ah][al][bl]
        mov     bl, al   ; Extract lowest byte of the code
        and     bl, 0x0F ; Consider only 4 first bits (lowest nibble)

        mov     bh, ah   ; Extract highest byte of the code
        and     bh, 0xF0 ; Consider only 4 last bits (highest nibble)
        shr     bh, NIB  ; Remove trailing zeroes

        and     ah, 0x0F ; Extract second highest nibble
        and     al, 0xF0 ; Extract second lowest nibble
        shr     al, NIB  ; Remove trailing zeroes

; Check if instruction is from A2 and if so, execute it.
execute_a2:
        cmp     bh, A2_HIMX ; If the highest nibble is not from range [0x0, 0x3]
        ja      execute_ai  ; then the instruction does not belong to A2.
mov:
        cmp     bl, MOV_LO
        jne     or
        ; TODO
        jmp     executed
or:
        cmp     bl, OR_LO
        jne     add
        ; TODO
        jmp     executed
add:
        cmp     bl, ADD_LO
        jne     sub
        ; TODO
        jmp     executed
sub:
        cmp     bl, SUB_LO
        jne     adc
        ; TODO
        jmp     executed
adc:
        cmp     bl, ADC_LO
        jne     sbb
        ; TODO
        jmp     executed
sbb:
        cmp     bl, SBB_LO
        jne     execute_ai
        ; TODO
        jmp     executed

; Check if instruction is from AI and if so, execute it.
execute_ai:
        cmp     bh, AI_HIMX ; If the highest nibble is not from range [0x4, 0x6]
        ja      execute_a1  ; then the instructions does not belong to AI.
        ; TODO
        mov     bl, ah ; Now bx holds the highest byte of the code
movi:
        cmp     bx, MOVI_BY
        jne     xori
        ; TODO
        ja      executed
xori:
        cmp     bx, XORI_BY
        ja      addi
        ; TODO
        jmp     executed
addi:
        cmp     bx, ADDI_BY
        ja      cmpi
        ; TODO
        jmp     executed
cmpi:
        cmp     bx, CMPI_BY
        ja      execute_a1
        ; TODO
        jmp     executed

; Check if instruction is from A1 and if so, execute it.
execute_a1:
        cmp     bh, A1_HIEX ; If the highest nibble is not equal to 0x7
        jne     execute_i1  ; then the instruction does not belong to A1.
; Argument value is encoded on the second highest nibble.
rcr:
        cmp     al, RCR_2LO
        jne     executed
        ; TODO
        jmp     executed ; Ignore unmatched instruction

execute_i1:
        cmp     bh, I1_HIEX ; If the highest nibble is not equal to 0xC
        jne     execute_a0  ; then the instruction does not belong to I1

; Immediate value is encoded on the lowest byte.
        shl     al, NIB
        or      bl, al
jmp:
        cmp     ah, JMP_2HI
        jne     jnc
        add     byte [rsp + PC_CNT], bl
        jmp     executed
jnc:
        cmp     ah, JNC_2HI
        jne     jc
        ; TODO
        jmp     executed
jc:
        cmp     ah, JC_2HI
        jne     jnz
        ; TODO
        jmp     executed
jnz:
        cmp     ah, JNZ_2HI
        jne     jz
        ; TODO
        jmp     executed
jz:
        cmp     ah, JZ_2HI
        jne     execute_a0
        ; TODO
        jmp     executed

; *Assume* instruction is from A0 and if it is, execute it.
; Second highest nibble represents instruction type.
execute_a0:
; No need to check if instruction category is indeed A0.
clc:
        cmp     ah, CLC_2HI
        jne     stc
        mov     byte [rsp + C_FLAG], 0 ; Clear virtual carry factor
        jmp     executed
stc:
        cmp     ah, STC_2HI
        jne     brk
        mov     byte [rsp + C_FLAG], 1 ; Set virtual carry factor
        jmp     executed
brk:
        cmp     ah, BRK_2HI
        jne     executed    ; Ignore unmatched instruction
        jmp     build_state ; Terminate the program

executed:
        inc     byte [rsp + PC_CNT] ; Increment PC counter
        dec     rdx                 ; Decrement steps left to perform
        jnz     steps_loop          ; Repeat steps_loop until steps is zero
build_state:
        mov     rax, qword [rsp]
        add     rsp, CPU_SZ
        pop     rbx
end_program:
        ret