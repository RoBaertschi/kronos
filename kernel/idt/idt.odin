package kronos_idt

import "base:runtime"
import "kernel:cpu"

@require foreign import idt "idt.asm"

@(export)
exception_handler :: proc(interrupt: u8) {
    runtime.print_u64(u64(interrupt))
    cpu.halt_catch_fire()
}

IDT_SIZE :: 256 // sync with idt.asm

foreign idt {
    // NOTE(robin): because we cannot specify the alignment of a global, we do it in assembly
    idt: [IDT_SIZE]cpu.Encoded_Idt_Entry
}

