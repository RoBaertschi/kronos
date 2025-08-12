package kronos_idt

import "base:runtime"
import "kernel:cpu"

@require foreign import idt "idt.asm"

@(export)
exception_handler :: proc(interrupt: u8) {
    runtime.print_u64(u64(interrupt))
    cpu.halt_catch_fire()
}

Interrupt_Context :: struct {
    r15: u64,
    r14: u64,
    r13: u64,
    r12: u64,
    r11: u64,
    r10: u64,
    r9: u64,
    r8: u64,
    rsi: u64,
    rdx: u64,
    rdi: u64,
    rcx: u64,
    rbx: u64,
    rax: u64,

    vector_number: u64,
    error_code: u64,

    iret_rip: u64,
    iret_cs: u64,
    iret_flags: u64,
    iret_rsp: u64,
    iret_ss: u64,
}

IDT_SIZE :: 256 // sync with idt.asm

foreign idt {
    // NOTE(robin): because we cannot specify the alignment of a global, we do it in assembly
    idt: [IDT_SIZE]cpu.Encoded_Idt_Entry
}

