global so_emul

section .rodata
mx_arg: dw      7      ; Maximal argument value
arg1_c: dw      0x100  ; Coefficient for first argument
arg2_c: dw      0x0800 ; Coefficient for second argument
codes:  dw      0x0000, 0x4000
labels: dq      mov, movi

section .text
so_emul:
        ret