cpu x86-64
bits 64

global halt_catch_fire
global enable_sse
global set_gdt
global set_idt
global get_cr2
global get_cr3
global set_cr3
global magic_breakpoint


section .text

halt_catch_fire:
    call magic_breakpoint
    cli
.loop:
    hlt
    jmp .loop

magic_breakpoint:
    xchg bx, bx
    ret

enable_sse:
    mov rax, cr0
    and ax, 0xfffb
    or ax, 0x2
    mov cr0, rax
    mov rax, cr4
    or ax, 3 << 9
    mov cr4, rax
    ret

get_cr2:
    mov rax, cr2
    ret

get_cr3:
    mov rax, cr3
    ret

set_cr3:
    mov cr3, rdi
    ret

get_rsp:
    mov rax, rsp
    sub rax, 8
    ret

; di  limit
; rsi base
set_gdt:
    mov [rel gdtr], di
    mov [rel gdtr+2], rsi
    lgdt [rel gdtr]
    ret

; di  limit
; rsi base
set_idt:
    cli
    mov [rel idtr], di
    mov [rel idtr+2], rsi
    lidt [rel idtr]
    sti
    ret

section .data
gdtr DW 0 ; limit
     DQ 0 ; base

idtr DW 0 ; limit
     DQ 0 ; base
