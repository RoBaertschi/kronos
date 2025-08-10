package kronos_cpu

@require foreign import kernel "kernel.asm"

foreign kernel {
    halt_catch_fire :: proc "sysv"() -> ! ---
    enable_sse :: proc "sysv"() ---
    set_gdt :: proc "sysv"(limit: u16, base: uintptr) ---
}

Gdt_Entry :: struct {
    limit:       u32, // max u20
    base:        uintptr,
    access_byte: u8,
    flags:       u8,
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

encode_gdt_entry :: proc(target: ^u64, desc: Gdt_Entry) {
    assert(desc.limit <= 0xFFFFF)

    target := cast([^]u8)target

    // Limit
    target[0] = u8( desc.limit        & 0xFF)
    target[1] = u8((desc.limit >>  8) & 0xFF)
    target[6] = u8((desc.limit >> 16) & 0xFF)

    // Base
    target[2] = u8( desc.base        & 0xFF)
    target[3] = u8((desc.base >>  8) & 0xFF)
    target[4] = u8((desc.base >> 16) & 0xFF)
    target[7] = u8((desc.base >> 24) & 0xFF)

    // Access byte
    target[5] = desc.access_byte

    // flags
    target[6] |= (u8(desc.flags) << 4)

}

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
