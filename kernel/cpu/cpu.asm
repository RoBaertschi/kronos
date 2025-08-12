cpu x86-64
bits 64

global halt_catch_fire
global enable_sse
global set_gdt
global set_idt


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
    cti
    mov [rel idtr], di
    mov [rel idtr+2], rsi
    lidt [rel idtr]
    sti

    int 0x80
    ret

section .data
gdtr DW 0 ; limit
     DQ 0 ; base

idtr DW 0 ; limit
     DQ 0 ; base
