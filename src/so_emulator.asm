; Solution modifies rbx, rax, r8-15 registers and preserved rbx, r12-r15.
; Content of registers A, D, X, Y, PC is located inside r8b, r9b, 10b, r11b, r12b.
; The following naming conventions are used: rdi - code, rsi - data, rdx - steps.

global so_emul

STATE   equ 8 ; Bytes required to store CPU state

; Indecis of CPU registers, flags and counter located inside rsp register.
; E.g. content of register X is [rsp + X_REG], carry flag is [rsp + C_FLG]
A_REG   equ 0
D_REG   equ 1
X_REG   equ 2
Y_REG   equ 3
PC_CNT  equ 4
C_FLG   equ 6
Z_FLG   equ 7

; Numerical values of arguments to encode virtual memory content.
; Values from 0 to 4 correpond to A, D, X, Y (same order as in CPU state)
; E.g. XD_MEM corresponds to [X + D], X_MEM to [X].
X_MEM   equ 4
Y_MEM   equ 5
XD_MEM  equ 6
YD_MEM  equ 7

MX_ARG  equ 7      ; Maximal argument value
MX_IMM  equ 0xff   ; Maximal immediate value
ARG1_C  equ 0x100  ; Code of first argument
ARG2_C  equ 0x0800 ; Code of second argument

; Codes of instructions
MOV_C   equ 0x0000
OR_C    equ 0x0002
ADD_C   equ 0x0004
SUB_C   equ 0x0005
ADC_C   equ 0x0006
SBB_C   equ 0x0007
MOVI_C  equ 0x4000
XORI_C  equ 0x5800
ADDI_C  equ 0x6000
CMPI_C  equ 0x6800
RCR_C   equ 0x7001
CLC_C   equ 0x8000
STC_C   equ 0x8100
JMP_C   equ 0xC000
JNC_C   equ 0xC200
JC_C    equ 0xC300
JNZ_C   equ 0xC400
JZ_C    equ 0xC500
BRK_C   equ 0xFFFF

; TODO: get rid of pushs ?
; TODO: compare program size with .rodata

section .text

match_arg: ; TODO: ch, cl
        cmp     al, Y_REG
        mov     al, byte [rsp + rax]
        jna     return
return:
        ret

so_emul:
        xor     r8, r8
        xor     r9, r9
        sub     rsp, STATE
state_loop:
        ; TODO loop to clear rsp stack
        mov     byte [rsp], 0
        xor     r8, r8 ; Index of the next instruction to execute
steps_loop: ; for (; steps > 0; steps--)
        mov     r9w, word [rdi + r8 * 2] ; Value of instruction to execute: code[r8]
        ; TODO noarg check
        ; TODO imm1 check
        xor     r10w, r10w ; Clear loop variable for arg1_loop
arg1_loop: ;  for (uint16_t arg1 = 0; arg1 < mx_arg; arg1++)
        call    match_arg
        mov     cl, al

        mov     ax, ARG1_C
        mul     r10w
        mov     bx, ax ; bx = 0x100 * arg1

        mov     ax, r9w
        sub     ax, bx
        sub     ax, MOVI_C ; ax = current instruction code - movi code - 0x100 * arg1
        mov     ch, al
        cmp     ch, MX_IMM
        jna     movi

        ; TODO

        xor     r11w, r11w ; Clear loop variable for arg2_loop
arg2_loop: ;  for (uint16_t arg2 = 0; arg2 < mx_arg; arg2++)
        call    match_arg
        mov     ch, al

        mov     ax, ARG2_C
        mul     r11w
        add     bx, ax ; bx += 0x0800 * arg2

        mov     ax, MOV_C
        add     ax, bx ; ax = mov code + 0x100 * arg1 + 0x0800 * arg2
        cmp     ax, r9w
        je      mov

        ; TODO

        cmp     r11w, MX_ARG
        inc     r11w
        jna     arg2_loop

        cmp     r10w, MX_ARG
        inc     r10w
        jna     arg1_loop

executed:
        inc     r8
        dec     rdx
        jnz     steps_loop

        ; TODO build state

        jmp     end

mov:
        mov     cl, ch
        jmp     end
movi:
        mov     cl, ch
        jmp     end
end:
        mov     al, byte [rsp]
        add     rsp, STATE
        ret