cpu x86-64
bits 64

global outb
global inb

section .text

; di port
; si value
; does not return anything
outb:
    mov DX, DI
    mov RAX, RSI
    out DX, AL
    ret

; di port
; returns a byte
inb:
    mov DX, DI
    in AL, DX
    ret
