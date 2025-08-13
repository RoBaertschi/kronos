package kronos_idt

import "base:runtime"
import "kernel:cpu"

IDT_SIZE :: 256 // sync with idt.asm

@require foreign import idt_asm "idt.asm"

Interrupt_Context :: struct {
    r15: u64,
    r14: u64,
    r13: u64,
    r12: u64,
    r11: u64,
    r10: u64,
    r9:  u64,
    r8:  u64,
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

@(export)
exception_handler :: proc "sysv" (ctx: ^Interrupt_Context) -> ^Interrupt_Context {
    runtime.print_string(interrupt_get_mnemonic(u8(ctx.vector_number)))
    runtime.print_string(" - ")
    runtime.print_string(interrupt_name(u8(ctx.vector_number)))

    if interrupt_has_error_code(u8(ctx.vector_number)) {
        runtime.print_string(": ")
        runtime.print_u64(ctx.error_code)
    }
    runtime.print_string("\n")
    cpu.halt_catch_fire()
}

set_idt_entry :: proc(pos: u8, entry: cpu.Idt_Entry) {
    cpu.encode_idt_entry(&idt[pos], entry)
}

init :: proc() {
    for i in 0..<IDT_SIZE {
        set_idt_entry(u8(i), {
            offset           = uintptr(isr_stub_table[i]),
            ist              = 0,
            gate_type        = .Interrupt,
            dpl              = .Ring_0,
            p                = true,
            segment_selector = 0x8,
        })
    }

    cpu.set_idt(size_of(cpu.Encoded_Idt_Entry) * IDT_SIZE - 1, uintptr(&idt[0]))
}


foreign idt_asm {
    // NOTE(robin): because we cannot specify the alignment of a global, we do it in assembly
    idt: [IDT_SIZE]cpu.Encoded_Idt_Entry
    isr_stub_table: [IDT_SIZE]rawptr
}

