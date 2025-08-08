cpu x86-64
bits 64

global halt_catch_fire

section .text

halt_catch_fire:
    cli
.loop:
    hlt
    jmp .loop
