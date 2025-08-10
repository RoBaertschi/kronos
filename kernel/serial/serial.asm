cpu x86-64
bits 64

global outb
global inb

section .text

; di port
; si value
; does not return anything
outb:
    mov dx, di
    mov rax, rsI
    out dx, al
    ret

; di port
; returns a byte
inb:
    mov dx, di
    in al, dx
    ret
