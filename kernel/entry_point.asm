cpu x86-64
bits 64

global _start
extern halt_catch_fire
extern kmain
extern enable_sse

_start:
    mov rdi, rsp
    sub rdi, 8 ; pop the pushed return address

    push rbp
    mov rbp, rsp

    call enable_sse
    call kmain

ohno:
    call halt_catch_fire
    jmp ohno
