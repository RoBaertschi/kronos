cpu x86-64
bits 64

global halt_catch_fire
global enable_sse

section .text

halt_catch_fire:
    cli
.loop:
    hlt
    jmp .loop

enable_sse:
    mov rax, cr0
    and ax, 0xfffb
    or ax, 0x2
    mov cr0, rax
    mov rax, cr4
    or ax, 3 << 9
    mov cr4, rax
    ret
