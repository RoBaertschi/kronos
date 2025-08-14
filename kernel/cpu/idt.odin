package kronos_cpu

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
