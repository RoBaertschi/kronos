package kronos_serial

@require foreign import lib "serial.asm"

foreign lib {
    outb :: proc "sysv"(port: u16, value: u8) ---
    inb  :: proc "sysv"(port: u16) -> u8 ---
}

PORT :: 0x3f8 // COM1

init :: proc "contextless" () -> bool {
    outb(PORT + 1, 0x00)    // Disable all interrupts
    outb(PORT + 3, 0x80)    // Enable DLAB (set baud rate divisor)
    outb(PORT + 0, 0x03)    // Set divisor to 3 (lo byte) 38400 baud
    outb(PORT + 1, 0x00)    //                  (hi byte)
    outb(PORT + 3, 0x03)    // 8 bits, no parity, one stop bit
    outb(PORT + 2, 0xC7)    // Enable FIFO, clear them, with 14-byte threshold
    outb(PORT + 4, 0x0B)    // IRQs enabled, RTS/DSR set
    outb(PORT + 4, 0x1E)    // Set in loopback mode, test the serial chip
    outb(PORT + 0, 0xAE)    // Test serial chip (send byte 0xAE and check if serial returns same byte)

    if inb(PORT + 0) != 0xAE {
        return false
    }

    outb(PORT + 4, 0x0F)
    return true
}

is_transmit_empty :: proc "contextless" () -> bool {
    return (inb(PORT + 5) & 0x20) != 0
}

write_byte :: proc "contextless" (data: u8) {
    for !is_transmit_empty() {}

    outb(PORT, data)
}

write :: proc "contextless" (data: []u8) {
    for b in data {
        write_byte(b)
    }
}

write_any :: proc "contextless" (data: $T) {
    data := data
    data_bytes := transmute([size_of(data)]u8)data
    write(data_bytes[:])
}

write_string :: proc "contextless" (s: string) {
    write(raw_data(s)[:len(s)])
}
