package kronos_cpu

@require foreign import cpu "cpu.asm"

foreign cpu {
    halt_catch_fire :: proc "sysv"() -> ! ---
    enable_sse :: proc "sysv"() ---
    set_gdt :: proc "sysv"(limit: u16, base: uintptr) ---
    set_idt :: proc "sysv"(limit: u16, base: uintptr) ---
    get_cr3 :: proc "sysv"() -> u64 ---
    set_cr3 :: proc "sysv"(val: u64) ---
}

// Segment_Descriptor_Access_Byte :: bit_field u8 {
//     A:   bool | 1,
//     RW:  bool | 1,
//     DC:  bool | 1,
//     E:   bool | 1,
//     S:   bool | 1,
//     DPL: u8   | 2,
//     P:   bool | 1,
// }
//
// Segment_Descriptor_Flag :: enum u8 {
//     Reserved,
//     L,
//     DB,
//     G,
// }
//
// Segment_Descriptor_Flags :: bit_set[Segment_Descriptor_Flag; u8]


// Segment_Descriptor :: bit_field u64 {
//     limit:          u16 | 16,
//     base_low:       u16 | 16,
//     base_high_low:  u8  | 8,
//     access_byte:    u8  | 8,
//     limit_rest:     u8  | 4,
//     flags:          u8  | 4,
//     base_high_high: u8  | 8,
// }
//
// default_gdt_segments := [?]Segment_Descriptor{
//     {},
//     { limit = 0xFFFF, limit_rest = 0xF, access_byte = 0x9A, flags = 0xA },
//     { limit = 0xFFFF, limit_rest = 0xF, access_byte = 0x92, flags = 0xC },
//     { limit = 0xFFFF, limit_rest = 0xF, access_byte = 0xFA, flags = 0xA },
//     { limit = 0xFFFF, limit_rest = 0xF, access_byte = 0xF2, flags = 0xC },
//
//     // TODO(robin): TSS
// }

//
//
