package kronos_allocator_physical

import "base:runtime"

import "core:io"
import "core:fmt"
import "core:math"

PAGE_SIZE :: 4 * runtime.Kilobyte

Physical_Allocator :: struct {
    base:   uintptr,
    data:   []byte,
    levels: int,
}

MAX_LEVEL :: 7 // 512 KiB blocks

init_physical_allocator :: proc(a: ^Physical_Allocator, data: []byte, base: uintptr) {
    level := 1
    x: int

    for level < MAX_LEVEL {
        increment := int(math.pow2_f32(f32(level)))
        x += increment
        if x >= (len(data) * 8)-2 {
            break
        }
        level += 1
    }

    a.base = base
    a.data = data
    a.levels = level
}

get_bit_idx_in_bytes :: proc(i: int) -> (int, u8) {
    return i / 8, u8(i % 8)
}

get_bit_in_bytes :: proc(i: int, bytes: []byte) -> bool {
    idx, bit := get_bit_idx_in_bytes(i)
    return ((bytes[idx] >> bit) & 0b1) != 0
}

get_level_pos :: proc(a: Physical_Allocator, level: int) -> int {
    e := math.pow2_f32(f32(level))
    return int(f32(len(a.data) * 8) * (1 - 1 / e))
}

get_level_bounds :: proc(a: Physical_Allocator, level: int) -> (start, end: int) {
    start = get_level_pos(a, level)
    end = get_level_pos(a, level + 1)
    return
}

write_bit :: proc(w: io.Writer, value: bool) {
    if value {
        io.write_rune(w, '#')
    } else {
        io.write_rune(w, '.')
    }
}

write_allocator_usage :: proc(w: io.Writer, a: Physical_Allocator) {
    fmt.wprintfln(w, "Physical_Allocator(base = %v, levels = %v):", a.base, a.levels)

    io.write_string(w, "all: ")

    root_level_start, root_level_end := get_level_bounds(a, 0)
    for i in root_level_start..<root_level_end {
        write_bit(w, get_bit_in_bytes(i, a.data))
    }
    io.write_rune(w, '\n')
    io.write_rune(w, '\n')

    for i in 0..<a.levels {
        start, end := get_level_bounds(a, i)

        fmt.wprintf(w, "% 3d: ", i)
        for j in start..<end {
            write_bit(w, get_bit_in_bytes(j, a.data))

            for _ in 1..<math.pow2_f32(f32(i)) {
                io.write_rune(w, ' ')
            }
        }
        io.write_rune(w, '\n')
    }
}
