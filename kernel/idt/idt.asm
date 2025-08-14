cpu x86-64
bits 64

section .text

extern exception_handler
interrupt_stub:
    push rax
    push rbx
    push rcx
    push rdi
    push rdx
    push rsi
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    mov rdi, rsp
    call exception_handler
    mov rsp, rax

    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rsi
    pop rdx
    pop rdi
    pop rcx
    pop rbx
    pop rax

    ; Remove vector and error code
    add rsp, 16
    iretq

%macro isr_err_stub 1
ALIGN 16
isr_stub_%+%1:
    push 0
    push %1
    call interrupt_stub
    iretq
%endmacro

%macro isr_no_err_stub 1
ALIGN 16
isr_stub_%+%1:
    push 0
    push %1
    call interrupt_stub
    iretq
%endmacro

%define IDT_SIZE 256

isr_no_err_stub 0
isr_no_err_stub 1
isr_no_err_stub 2
isr_no_err_stub 3
isr_no_err_stub 4
isr_no_err_stub 5
isr_no_err_stub 6
isr_no_err_stub 7
isr_err_stub    8
isr_no_err_stub 9
isr_err_stub    10
isr_err_stub    11
isr_err_stub    12
isr_err_stub    13
isr_err_stub    14
isr_no_err_stub 15
isr_no_err_stub 16
isr_err_stub    17
isr_no_err_stub 18
isr_no_err_stub 19
isr_no_err_stub 20
isr_no_err_stub 21
isr_no_err_stub 22
isr_no_err_stub 23
isr_no_err_stub 24
isr_no_err_stub 25
isr_no_err_stub 26
isr_no_err_stub 27
isr_no_err_stub 28
isr_no_err_stub 29
isr_err_stub    30
isr_no_err_stub 31

%assign i 32
%rep (IDT_SIZE-31)
isr_no_err_stub i
%assign i i+1
%endrep

section .data
global isr_stub_table
isr_stub_table:
%assign i 0
%rep    IDT_SIZE
    dq isr_stub_%+i
%assign i i+1
%endrep

global idt

section .bss

ALIGN 0x1000 ; Page size
idt:
    times IDT_SIZE resq 2
