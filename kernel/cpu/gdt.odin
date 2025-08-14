package kronos_cpu

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

