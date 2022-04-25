; Solution modifies the following registers: rax, rsi, r8, r9, r10, r11.

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

; Indices of CPU state attributes:
A_REG   equ 0
D_REG   equ 1
X_REG   equ 2
Y_REG   equ 3
PC_CNT  equ 4
C_FLAG  equ 6
Z_FLAG  equ 7

MOD_MSK equ 7 ; Mask for modulo 8 reduction

; Values referring to virtual memory and registers. Smaller entries (0-4)
; correspond to values of virtual registers (same order as in CPU state).
X_MEM   equ 4
Y_MEM   equ 5
XD_MEM  equ 6
YD_MEM  equ 7

SSZ     equ 8 ; State size: number of bytes required to store a CPU state.
LOG_SSZ equ 3 ; Value of log_2(SSZ) for fast multiplication

; Define number of cores for a single-core emulation.
%ifndef CORES
%define CORES 1
%endif

; *NOTE*: From this point we assume that r15 is *always* holding an address
; to the CPU state of the processing core. To address specific attributes
; we simply do "mov reg8, byte [r15 + attr_idx]", where attr_idx belongs to set
; {A_REG, D_REG, X_REG, Y_REG, C_FLAG, Z_FLAG, PC_CNT}.

; Sets a virtual flag of the processing core.
; Parameter must be either C_FLAG or Z_FLAG.
%macro setf 1
        mov    byte [r15 + %1], 1
%endmacro

; Clears a virtual of the processing core.
; Parameter must be either C_FLAG or Z_FLAG.
%macro clrf 1
        mov    byte [r15 + %1], 0
%endmacro


; Updates a virtual carry flag with the result of the last operation.
update_cf:
        jc     .carry
        clrf   C_FLAG
        jmp    .updated
.carry:
        setf   C_FLAG
.updated:
        ret

; Updates a virtual zero flag with the result of the last operation.
update_zf:
        jz     .zero
        clrf   Z_FLAG
        jmp    .updated
.zero:
        setf   Z_FLAG
.updated:
        ret

; Matches real carry flag value with the value of a virtual one.
match_cf:
        cmp    byte [r15 + C_FLAG], 0
        je     .clear
.set:
        stc
        jmp    .matched
.clear:
        clc
.matched:
        ret


section .bss

; Global table holding a CPU state of each core
states: resb CORES * SSZ

section .text

; Writes to r9b value of a virtual register or
; memory matching an argument (0-7) stored in al.
; Modifies the following registers: r9b, r10b, r11b, r12b
get_argument:
        push    rax
        and     rax, 0xFF ; Consider only al for indexing
; If argument is not greater than 3, then it referres to a register.
        cmp     al, Y_REG
        ja      .x_mem
        mov     r9b, byte [r15 + rax]    ; Read value of a register from the CPU state
        jmp     .matched
; Otherwise, we check though each value referring to an adressed memory.
.x_mem:
        mov     r10b, byte [r15 + X_REG] ; Read value of register X
        cmp     al, X_MEM
        jne     .y_mem
        mov     r9b, byte [rsi + r10]    ; Return value of [X]
        jmp     .matched
.y_mem:
        mov     r11b, byte [r15 + Y_REG] ; Read value of register Y
        cmp     al, Y_MEM
        jne     .xd_mem
        mov     r9b, byte [rsi + r11]    ; Return value of [Y]
        jmp     .matched
.xd_mem:
        mov     r12b, byte [r15 + D_REG] ; Read value of register D
        cmp     al, XD_MEM
        jne     .yd_mem
        add     r12b, r10b               ; Now r12b holds value of X + D
        mov     r9b, byte [rsi + r12]    ; Return value of [X + D]
        jmp     .matched
.yd_mem:
        cmp     al, YD_MEM
        jne     .matched                 ; Ignore argument not in range [0, 7]
        add     r12b, r11b               ; Now r12b holds value of X + D
        mov     r9b, byte [rsi + r12]    ; Return value of [Y + D]
.matched:
        pop     rax
        ret


; Sets r9b as the value of a virtual register or
; memory matching an arguent (0-7) stored in al.
; Modifies the following registers: r10b, r11b, r12b.
set_argument:
        push    rax
        and     rax, 0xFF ; Consider only al for indexing
; If argument is not greater than 3, then it referes to a register.
        cmp     al, Y_REG
        ja      .x_mem
        mov     byte [r15 + rax], r9b ; Update value of a register in CPU state
        jmp     .matched
; Otherwise, we check though each value referring to an adressed memory.
.x_mem:
        mov     r10b, byte [r15 + X_REG] ; Read value of register X
        cmp     al, X_MEM
        jne     .y_mem
        mov     byte [rsi + r10], r9b    ; Set value of [X]
        jmp     .matched
.y_mem:
        mov     r11b, byte [r15 + Y_REG] ; Read value of register Y
        cmp     al, Y_MEM
        jne     .xd_mem
        mov     byte [rsi + r11], r9b    ; Set value of [Y]
        jmp     .matched
.xd_mem:
        mov     r12b, byte [r15 + D_REG] ; Read value of register D
        cmp     al, XD_MEM
        jne     .yd_mem
        add     r12b, r10b               ; Now r12b holds value of X + D
        mov     byte [rsi + r12], r9b    ; Set value of [X + D]
        jmp     .matched
.yd_mem:
        cmp     al, YD_MEM
        jne     .matched                 ; Ignore argument not in range [0, 7]
        add     r12b, r11b               ; Now r12b holds the value of of Y + D
        mov     byte [rsi + r12], r9b    ; Set value of [Y + D]
.matched:
        pop     rax
        ret


so_emul:
        xor     rax, rax  ; Clear register for return value
        test    rdx, rdx  ; If program consists of 0 steps
        jz      terminate ; Leave CPU state unmodified and end program

; Preserve nonvolatile registers
        push    rbx
        push    r12
        push    r13
        push    r15

; Clear registers for storing temporary values
        xor     r8, r8
        xor     r9, r9
        xor     r10, r10
        xor     r11, r11
        xor     r12, r12
        xor     r13, r13
        xor     rbx, rbx

; If emulating with invalid number of cores, which is
; strictly greater than CORES, set current core number to zero.
        cmp     rcx, CORES
        jna     valid_core
        xor     rcx, rcx

valid_core:
        shl     rcx, LOG_SSZ      ; Multiply current core number by 8
        lea     r15, [rel states] ; Read address of the first core CPU state
        add     r15, rcx          ; Now r15 addresses CPU state of the current core

steps_loop:
        mov     r8b, byte [r15 + PC_CNT] ; Read index of the current instruction
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

; Second argument is encoded on the [11-13] bits indexing from 0:
        shl     bh, NIB       ; Creating trailing zeroes in the highest nibble
        or      bh, ah        ; Store the highest byte in bh
        and     bh, 00111000b ; Consider only bits from range [11-13]
        shr     bh, LOG_SSZ   ; Remove trailing zeroes
        mov     al, bh        ; Prepare a parameter for get_argument
        call    get_argument  ; Now r9b holds the value to which second argument refers
        mov     r13b, r9b     ; Temporarily store the result in other register

; First argument is encoded on the second highest nibble modulo 8:
        and     ah, MOD_MSK  ; Reduce modulo 8 by masking 3 lowest bits
        mov     al, ah       ; Prepare a parameter for get_argument
        call    get_argument ; Now r9b holds the value to which first argument refers

; Instruction type is encoded on the lowest nibble.
mov:
        cmp     bl, MOV_LO
        jne     or
        mov     r9b, r13b
        jmp     success_a2
or:
        cmp     bl, OR_LO
        jne     add
        or      r9b, r13b
        call    update_zf
        jmp     success_a2
add:
        cmp     bl, ADD_LO
        jne     sub
        add     r9b, r13b
        call    update_zf
        jmp     success_a2
sub:
        cmp     bl, SUB_LO
        jne     adc
        sub     r9b, r13b
        call    update_zf
        jmp     success_a2
adc:
        cmp     bl, ADC_LO
        jne     sbb
        call    match_cf
        adc     r9b, r13b
        call    update_zf
        call    update_cf
        jmp     success_a2
sbb:
        cmp     bl, SBB_LO
        jne     execute_ai
        call    match_cf
        sbb     r9b, r13b
        call    update_zf
        call    update_cf
        jmp     success_a2
success_a2:
        call    set_argument ; Parameter is prepared, set updated first argument
        jmp     executed

; Check if instruction is from AI and if so, execute it.
execute_ai:
        cmp     bh, AI_HIMX ; If the highest nibble is not from range [0x4, 0x6]
        ja      execute_a1  ; then the instructions does not belong to AI.

; Instruction type is encoded on the highest byte
        shl     bh, NIB ; Create trailing zeroes in the highest nibble
        or      bh, ah  ; Store instruction type in bh

; Immediate value is encoded on the lowest byte.
        shl     al, NIB ; Create trailing zeroes in second lowest nibble
        or      bl, al  ; Store immediate value in bl

; Argument is encoded on the second highest nibble modulo 8:
        mov     al, ah       ; Prepare parameter for get_argument call
        and     al, MOD_MSK  ; Reduce modulo 8 by masking lower bits
        call    get_argument ; Now r9b holds the value to which argument refers

movi:
        cmp     bh, MOVI_BY
        ja      xori
        mov     r9b, bl
        jmp     success_ai
xori:
        cmp     bh, XORI_BY
        ja      addi
        xor     r9b, bl
        call    update_zf
        jmp     success_ai
addi:
        cmp     bh, ADDI_BY
        ja      cmpi
        add     r9b, bl
        call    update_zf
        jmp     success_ai
cmpi:
        cmp     bh, CMPI_BY
        ja      execute_a1
        cmp     r9b, bl
        call    update_zf
        call    update_cf
        jmp     success_ai
success_ai:
        call    set_argument ; Parameter is prepared, set updated argument
        jmp     executed

; Check if instruction is from A1 and if so, execute it.
execute_a1:
        cmp     bh, A1_HIEX ; If the highest nibble is not equal to 0x7
        jne     execute_i1  ; then the instruction does not belong to A1

; Argument is encoded on the second highest nibble.
        xchg    al, ah ; Prepare parameter for call, second lowest nibble is now in ah
        call    get_argument ; Now r9b stores data to which argument refers

; Instruction type is encoded on the second lowest nibble.
rcr:
        cmp     ah, RCR_2LO
        jne     execute_i1
        call    match_cf ; Set CF is virtual CF is set
        rcr     r9b, 1   ; Perform a single rotation
        call    update_cf
        jmp     success_a1
success_a1:
        call    set_argument ; Parameter is prepared, set updated argument
        jmp     executed

execute_i1:
        cmp     bh, I1_HIEX ; If the highest nibble is not equal to 0xC
        jne     execute_a0  ; then the instruction does not belong to I1

; Immediate value is encoded on the lowest byte.
        shl     al, NIB ; Create trailing zeroes in second lowest nibble
        or      bl, al  ; Store the lowest byte in bl

; Instruction type is encoded on the second highest nibble.
jmp:
        cmp     ah, JMP_2HI
        jne     jnc
        add     byte [r15 + PC_CNT], bl ; Unconditionally increase PC counter
        jmp     executed
jnc:
        cmp     ah, JNC_2HI
        jne     jc
        cmp     byte [r15 + C_FLAG], 0
        jne     executed
        add     byte [r15 + PC_CNT], bl
        jmp     executed
jc:
        cmp     ah, JC_2HI
        jne     jnz
        cmp     byte [r15 + C_FLAG], 1
        jne     executed
        add     byte [r15 + PC_CNT], bl
        jmp     executed
jnz:
        cmp     ah, JNZ_2HI
        jne     jz
        cmp     byte [r15 + Z_FLAG], 0
        jne     executed
        add     byte [r15 + PC_CNT], bl
        jmp     executed
jz:
        cmp     ah, JZ_2HI
        jne     execute_a0
        cmp     byte [r15 + Z_FLAG], 1
        jne     executed
        add     byte [r15 + PC_CNT], bl
        jmp     executed

; *Assume* instruction is from A0 and if it is, execute it.
execute_a0:
; Instruction type is encoded on the second highest nibble.
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
        jmp     end_emulation

executed:
        inc     byte [r15 + PC_CNT] ; Increment PC counter
        dec     rdx                 ; Decrement steps left to perform
        jnz     steps_loop          ; Repeat steps_loop until steps is zero

end_emulation:
; Use CPU state as the return value
        mov     rax, qword [r15]

; Retrieve preserved registers
        pop     r15
        pop     r13
        pop     r12
        pop     rbx

terminate:
        ret