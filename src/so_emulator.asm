; Solution modifies the following registers: rax, rdi, rsi, r8, r9, r10.

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

NIB     equ 4 ; Bits per nibble

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

; Value to subtract from XORI and CMPI second highest nibbles to match an argument
AI_ARG  equ 0x8

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

ST_SIZE equ 8 ; Bytes required to store a CPU state

; Values referring to virtual memory and registers. Smaller entries (0-4)
; correspond to values of virtual registers (same order as in CPU state).
X_MEM   equ 4
Y_MEM   equ 5
XD_MEM  equ 6

; Sets a virtual flag. Parameter must be either C_FLAG or Z_FLAG.
%macro setf 1
        mov    byte [rsp + %1], 1
%endmacro

; Clears a virtual flag. Parameter must be either C_FLAG or Z_FLAG.
%macro clrf 1
        mov    byte [rsp + %1], 0
%endmacro

; Updates a virtual carry flag with the result of the last operation.
%macro updc 0
        jc     .carry
        clrf   C_FLAG
        ret
.carry:
        setf   C_FLAG
%endmacro

; Updates a virtual zero flag with the result of the last operation.
%macro updz 0
        jz     .zero
        clrf   Z_FLAG
        ret
.zero:
        setf   Z_FLAG
%endmacro

section .text

; Writes to r9b value of a virtual register or
; memory matching an argument (0-7) stored in ah.
; Modifies the following registers: r9b, r10b, r11b, r12b.
get_argument:
        push    rax
        and     rax, 0xFF00 ; Consider only ah for indexing
; If argument is not greater than 3, then it referres to a register.
        cmp     ah, Y_REG
        ja      .x_mem
        mov     r9b, byte [rsi + rax] ; Read value of a register
        jmp     .matched
; Otherwise, we check though each value referring to an adressed memory.
.x_mem:
        mov     r10b, byte [rsp + X_REG] ; Write value of register X
        cmp     ah, X_MEM
        jne     .y_mem
        mov     r9b, byte [rsi + r10] ; Read value of [X]
        jmp     .matched
.y_mem:
        mov     r11b, byte [rsp + Y_REG] ; Write value of register Y
        cmp     ah, Y_MEM
        jne     .xd_mem
        mov     r9b, byte [rsi + r11] ; Read value of [Y]
        jmp     .matched
.xd_mem:
        mov     r12b, byte [rsp + D_REG] ; Write value of register D
        cmp     ah, XD_MEM
        jne     .yd_mem
        add     r12b, r10b ; Write value of X + D to r12b
        mov     r9b, byte [rsi + r12] ; Read value of [X + D]
        jmp     .matched
.yd_mem:
        add     r12b, r11b ; Write value of Y + D to r12b
        mov     r9b, byte [rsi + r11] ; Read value of [Y + D]
.matched:
        pop     rax
        ret


; Sets r9b as the value of a virtual register or
; memory matching an arguent (0-7) stored in ah.
; Modifies the following registers: rsp, r10b, r11b, r12b.
set_argument:
        push    rax
        and     rax, 0xFF00 ; Consider only ah for indexing
; If argument is not greater than 3, then it referes to a register.
        cmp     ah, Y_REG
        ja      .x_mem
        mov     byte [rsi + rax], r9b ; Update value of a register
        jmp     .matched
; Otherwise, we check though each value referring to an adressed memory.
.x_mem:
        mov     r10b, byte [rsp + X_REG] ; Write value of register X
        cmp     ah, X_MEM
        jne     .y_mem
        mov     byte [rsi + r10], r9b ; Update value of [X]
        jmp     .matched
.y_mem:
        mov     r11b, byte [rsp + Y_REG] ; Write value of register Y
        cmp     ah, Y_MEM
        jne     .xd_mem
        mov     byte [rsi + r11], r9b ; Update value of [Y]
        jmp     .matched
.xd_mem:
        mov     r12b, byte [rsp + D_REG] ; Write value of register D
        cmp     ah, XD_MEM
        jne     .yd_mem
        add     r12b, r10b ; Write value of X + D to r12b
        mov     byte [rsi + r12], r9b ; Update value of [X + D]
        jmp     .matched
.yd_mem:
        add     r12b, r11b ; Write value of Y + D to r12b
        mov     byte [rsi + r10], r9b ; Update value of [Y + D]
        jmp     .matched
.matched:
        pop     rax
        ret

; TODO: preserve state
; TODO: thread safety

so_emul:
        xor     rax, rax    ; TODO
        test    rdx, rdx    ; If program consists of 0 steps
        jz      end_program ; Leave CPU state unmodified and end program

        push    rbx              ; Preserve nonvolatile rbx register
        push    r12
        sub     rsp, ST_SIZE     ; Allocate 8 bytes on stack for CPU state
        mov     qword [rsp], 0   ; TODO

; Clear registers for storing temporary values
        xor     r8, r8
        xor     r9, r9
        xor     r10, r10
        xor     r11, r11
        xor     r12, r12
        xor     rbx, rbx

steps_loop:
        mov     r8b, byte [rsp + PC_CNT] ; Read index of the current instruction
        mov     ax, word [rdi + r8 * 2]  ; Read code of current instruction

; Split instruction code by nibbles without trailing zeroes: 0x[bh][ah][al][bl]
        mov     bl, al   ; Extract lowest byte of the code
        and     bl, 0x0F ; Consider only 4 first bits (lowest nibble)

        mov     bh, ah   ; Extract highest byte of the code
        and     bh, 0xF0 ; Consider only 4 last bits (highest nibble)
        shr     bh, NIB  ; Remove trailing zeroes from the highest nibble

        and     ah, 0x0F ; Extract second highest nibble
        and     al, 0xF0 ; Extract second lowest nibble
        shr     al, NIB  ; Remove trailing zeroes from the second lowest nibble

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

; Instruction type is encoded on the highest byte
        shl     ah, NIB ; Create trailing zeroes in second highest nibble
        or      bh, ah  ; Store instruction type in bh
        shr     ah, NIB ; Retrieve the initial value of second nibble

; Immediate value is encoded on the lowest byte.
        shl     al, NIB ; Create trailing zeroes in second lowest nibble
        or      bl, al  ; Store immediate value in bl

; Argument is encoded on the second lowest nibble after subtracting
; the second highest nibble of initial instruction code:
; - for MOVI and ADDI it is 0
; - for XORI and CMPI it is 8, which is a AI_ARG constant

movi:
        cmp     bl, MOVI_BY
        ja      xori
        call    get_argument
        mov     r9b, bl
        call    set_argument
        jmp     executed
xori:
        cmp     bl, XORI_BY
        ja      addi
        call    get_argument
        xor     r9b, bl
        updz
        call    set_argument
        jmp     executed
addi:
        cmp     bl, ADDI_BY
        ja      cmpi
        call    get_argument
        add     r9b, bl
        updz
        call    set_argument
        jmp     executed
cmpi:
        cmp     bl, CMPI_BY
        ja      execute_a1
        sub     ah, AI_ARG
        call    get_argument
        cmp     r9b, bl
        updz
        updc
        call    set_argument
        jmp     executed
; Check if instruction is from A1 and if so, execute it.
execute_a1:
        cmp     bh, A1_HIEX ; If the highest nibble is not equal to 0x7
        jne     execute_i1  ; then the instruction does not belong to A1

; Encoding rules within the A1 category:
; - second lowest nibble encodes instruction type
; - second highest nibble encodes an argument

rcr:
        cmp     al, RCR_2LO
        jne     execute_i1
        call    get_argument ; Now r9b stores data to which argument refers
        rcr     r9b, 1       ; Perform a single rotateion
        call    set_argument ; Update virtual data
        jmp     executed

execute_i1:
        cmp     bh, I1_HIEX ; If the highest nibble is not equal to 0xC
        jne     execute_a0  ; then the instruction does not belong to I1

; Immediate value is encoded on the lowest byte.
        shl     al, NIB ; Create trailing zeroes in second lowest nibble
        or      bl, al  ; Sum two lowest nibbles, now bl is holding the lowest byte
jmp:
        cmp     ah, JMP_2HI
        jne     jnc
        add     byte [rsp + PC_CNT], bl ; Unconditionally increase PC counter
        jmp     executed
jnc:
        cmp     ah, JNC_2HI
        jne     jc
        cmp     byte [rsp + C_FLAG], 0  ; Check whether C flag is set:
        jne     executed                ; - if not set, do nothing
        add     byte [rsp + PC_CNT], bl ; - if set, increase PC counter
        jmp     executed
jc:
        cmp     ah, JC_2HI
        jne     jnz
        cmp     byte [rsp + C_FLAG], 1  ; Check whether C flag is set:
        jne     executed                ; - if set, do nothing
        add     byte [rsp + PC_CNT], bl ; - if not set, increase PC counter
        jmp     executed
jnz:
        cmp     ah, JNZ_2HI
        jne     jz
        cmp     byte [rsp + Z_FLAG], 0  ; Check whether Z flag is set:
        jne     executed                ; - if set, do nothing
        add     byte [rsp + PC_CNT], bl ; - if not set, increase PC counter
        jmp     executed
jz:
        cmp     ah, JZ_2HI
        jne     execute_a0
        cmp     byte [rsp + Z_FLAG], 1  ; Check whether Z flag is set
        jne     executed                ; - if not set, do nothing
        add     byte [rsp + PC_CNT], bl ; - if set, increase PC counter
        jmp     executed

; *Assume* instruction is from A0 and if it is, execute it.
; Second highest nibble represents instruction type.
execute_a0:
; No need to check if instruction category is indeed A0.
clc:
        cmp     ah, CLC_2HI
        jne     stc
        clrf    C_FLAG ; Use defined macro to clear the carry flag
        jmp     executed
stc:
        cmp     ah, STC_2HI
        jne     brk
        setf    C_FLAG  ; Use defined macro to set the carry flag
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
        add     rsp, ST_SIZE
        pop     r12
        pop     rbx
end_program:
        ret