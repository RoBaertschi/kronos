package kronos_cpu

@require foreign import kernel "kernel.asm"

foreign kernel {
    halt_catch_fire :: proc "sysv"() -> ! ---
    enable_sse :: proc "sysv"() ---
    set_gdt :: proc "sysv"(limit: u16, base: uintptr) ---
    set_idt :: proc "sysv"(limit: u16, base: uintptr) ---
    get_cr3 :: proc "sysv"() -> u64 ---
    set_cr3 :: proc "sysv"(val: u64) ---
}

Gdt_Entry :: struct {
    limit:       u32, // max u20
    base:        uintptr,
    access_byte: u8,
    flags:       u8,
}
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

Ring :: enum u8 {
    Ring_0 = 0,
    Ring_1 = 1,
    Ring_2 = 2,
    Ring_3 = 3,
}

#assert(u8(max(Ring)) == 3)

Idt_Entry_Gate_Type :: enum u8 {
    Interrupt = 0b1110,
    Trap      = 0b1111,
}
#assert(u8(max(Idt_Entry_Gate_Type)) <= 0xF)

Idt_Entry :: struct {
    offset:           uintptr,
    ist:              u8, // 3 bit value
    gate_type:        Idt_Entry_Gate_Type, // 4 bit value
    dpl:              Ring, // 2 bit value
    p:                bool,
    segment_selector: u16,
}

Encoded_Idt_Entry :: struct #packed {
    offset1:          u16,
    segment_selector: u16,
    ist:              u8, // bits 0..2 hold Interrupt Stack Table offset, rest reserved
    type_attributes:  u8, // gate type, dpl, and p fields
    offset2:          u16,
    offset3:          u32,

    _: u32, // reserved
}

#assert(size_of(Idt_Entry) == size_of(u128))

encode_idt_entry :: proc(target: ^Encoded_Idt_Entry, entry: Idt_Entry) {
    assert(entry.ist <= 0b111 && u8(entry.gate_type) <= 0b1111 && u8(entry.dpl) <= 0b11)
    target^ = {}

    target.offset1 = u16( entry.offset        & 0xFFFF)
    target.offset2 = u16((entry.offset >> 16) & 0xFFFF)
    target.offset3 = u32((entry.offset >> 32) & 0xFFFFFFFF)

    target.segment_selector = entry.segment_selector
    target.ist = entry.ist

    target.type_attributes |= u8(entry.gate_type) // gate type
    target.type_attributes |= u8(0)               << 4
    target.type_attributes |= u8(entry.dpl)       << 5
    target.type_attributes |= u8(entry.p ? 1 : 0) << 7 // P
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
