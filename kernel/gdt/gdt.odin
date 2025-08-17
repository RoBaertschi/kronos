package kronos_gdt

import "kernel:cpu"

gdt := [5]u64{}

init :: proc() {
    cpu.encode_gdt_entry(&gdt[0], {})
    cpu.encode_gdt_entry(&gdt[1], { limit = 0xFFFFF, access_byte = 0x9A, flags = 0xA })
    cpu.encode_gdt_entry(&gdt[2], { limit = 0xFFFFF, access_byte = 0x92, flags = 0xC })
    cpu.encode_gdt_entry(&gdt[3], { limit = 0xFFFFF, access_byte = 0xFA, flags = 0xA })
    cpu.encode_gdt_entry(&gdt[4], { limit = 0xFFFFF, access_byte = 0xF2, flags = 0xC })
    cpu.set_gdt(len(gdt)*size_of(gdt[0]) - 1, uintptr(&gdt))
}
