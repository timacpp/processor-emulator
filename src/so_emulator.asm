global so_emul

section .rodata
mx_arg: db      7      ; Maximal argument value
mx_imm: db      255    ; Maximal immediate value
arg1_c: dw      0x100  ; Coefficient for first argument
arg2_c: dw      0x0800 ; Coefficient for second argument
mov_c:  dw      0x0000 ; Coefficient for 'mov' instruction
movi_c: dw      0x4000 ; Coefficient for 'movi' instruction

section .text
; Solution modifies rbx, rax, r8-15 registers and preserved rbx, r12-r15.
; Content of registers A, D, X, Y, PC is located inside r8b, r9b, 10b, r11b, r12b.
; The following naming conventions are used: rdi - code, rsi - data, rdx - steps.
so_emul:
        push    rbx
        push    r14
        push    r15
        xor     r14, r14
        xor     r15, r15
        xor     rax, rax
        xor     rcx, rcx ; Index of code instruction to execute
steps_loop: ; for (; steps > 0; steps--)
        mov     r13w, word [rdi + rcx * 2] ; Value of instruction to execute: code[i]
        ; TODO noarg check
        ; TODO imm1 check
        xor     r14w, r14w ; Set loop variable for arg1_loop to zero
arg1_loop: ;  for (uint16_t arg1 = 0; arg1 < mx_arg; arg1++)
        mov     ax, [rel arg1_c]
        mul     r14w
        mov     bx, ax ; bx = 0x100 * arg1

        mov     ax, [rel mx_imm]
        add     ax, [rel movi_c]
        add     ax, bx
        cmp     ax, r13w
        jna     movi

        xor     r15w, r15w ; Set loop variable for arg2_loop to zero
arg2_loop: ;  for (uint16_t arg2 = 0; arg2 < mx_arg; arg2++)
        mov     ax, [rel arg2_c]
        mul     r15w
        add     bx, ax ; bx += 0x0800 * arg2

        mov     ax, [rel mov_c]
        add     ax, bx
        cmp     ax, r13w
        je      mov

        cmp     r15w, [rel mx_arg]
        inc     r15w
        jna     arg2_loop
; arg2_loop end
        cmp     r14w, [rel mx_arg]
        inc     r14w
        jna     arg1_loop
; arg1_loop end
executed:
        inc     rcx
        dec     rdx
        jnz     steps_loop
; steps_loop end
mov:
        xor     rax, rax
        jmp     end
movi:
        mov     rax, 1
        jmp     end
end:
        pop     r15
        pop     r14
        pop     rbx
        ret