; For the matter of simplicity I use term nibble to describe a single hexadecimal digit:
; 0x[highest nibble][second highest nibble][second lowest nibble][lowest nibble]

global so_emul

; Maximal value of the highest nibble of instructions:
A2_MAX  equ 0x3 ; - requiring two arguments
AI_MAX  equ 0x6 ; - requiring one argument and immediate value

; Exact value of the highest nibble of instructions:
A1_EXCT equ 0x7 ; - requiring only one argument
I1_EXCT equ 0xC ; - requiring only one immediate value

; Second highest nibbles of instructions without parameters
CLC_2HI equ 0x0
STC_2HI equ 0x1
BRK_2HI equ 0xF

; Second lowest nibbles of instructions with one argument
RCR_2LO equ 0x0

; Bytes required to store a CPU state
CPU_SZ  equ 8

; Indecis of virtual registers and flags values located on stack
A_REG   equ 0
D_REG   equ 1
X_REG   equ 2
Y_REG   equ 3
PC_CNT  equ 4
C_FLAG  equ 6
Z_FLAG  equ 7

section .text

so_emul:
        test    rdx, rdx    ; If program consists of 0 steps
        jz      end_program ; Leave CPU state unmodified and end program

        push    rbx              ; Preserve nonvolatile rbx register
        xor     r8, r8           ; Clear temporary variable for future use
        sub     rsp, CPU_SZ      ; Allocate 8 bytes on stack for CPU state
        mov     qword [rsp], rax ; Use previous CPU state parameters

steps_loop: ; for (; steps > 0; steps--)
        mov     r8b, byte [rsp + PC_CNT] ; Read index of the current instruction
        mov     ax, word [rdi + r8 * 2]  ; Read code of current instruction

        mov     bl, al   ; Extract lowest byte of the code
        and     bl, 0x0F ; Consider only 4 first bits (lowest nibble)

        mov     bh, ah   ; Extract highest byte of the code
        and     bh, 0xF0 ; Consider only 4 last bits (highest nibble)

        and     ah, 0x0F ; Extract second highest nibble
        and     al, 0xF0 ; Extract second lowest nibble
instructions_two_args:
        cmp     bh, A2_MAX
        ja      instructions_arg_imm8
        ; TODO

instructions_arg_imm8:
        cmp     bh, AI_MAX
        ja      instructions_one_arg
        ; TODO

instructions_one_arg:
; Argument value is encoded on the second highest nibble.
        cmp     bh, A1_EXCT
        jne     instructions_one_imm8
rcr:
        cmp     al, RCR_2LO
        jne     executed
        ; TODO: RCR
        jmp     executed

instructions_one_imm8:
        cmp     bh, I1_EXCT
        jne     instructions_no_args


instructions_no_args:
; Instruction type is encoded on the second highest nibble.
clc:
        cmp     ah, CLC_2HI ; 0x8[0]00
        jne     stc
        mov     byte [rsp + C_FLAG], 0 ; Clear virtual carry factor
        jmp     executed

stc:
        cmp     ah, STC_2HI ; 0x8[1]00
        jne     brk
        mov     byte [rsp + C_FLAG], 1 ; Set virtual carry factor
        jmp     executed

brk:
        cmp     ah, BRK_2HI ; 0xF[F]FF
        jne     executed    ; Ignore unmatched instruction
        jmp     build_state ; Break from the program

executed:
        inc     byte [rsp + PC_CNT]
        dec     rdx
        jnz     steps_loop

build_state:
        mov    rax, qword [rsp]
        add    rsp, CPU_SZ
        pop    rbx

end_program:
        ret