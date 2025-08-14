package kronos_allocator_physical

import "base:runtime"
_ :: runtime

// N = Pages
Allocator :: struct(N: int) \
    // Ensure that the amount of pages fit nicely into u64's
    where N % 64 == 0 && N > 0 {
    _4k:  [N / 64]u64, // 8
    _8k:  [N / 64]u32, // 4
    _16k: [N / 64]u16, // 2
    _32k: [N / 64]u8,  // 1
}

allocator_get_32k :: proc(block: int) -> (idx: int, bit: u8) {
    idx = block / 8
    bit = u8(block % 8)
    return
}

allocator_get_16k :: proc(block: int) -> (idx: int, bit: u8) {
    idx = block / 16
    bit = u8(block % 16)
    return
}

allocator_get_8k :: proc(block: int) -> (idx: int, bit: u8) {
    idx = block / 32
    bit = u8(block % 32)
    return
}

allocator_get_4k :: proc(block: int) -> (idx: int, bit: u8) {
    idx = block / 64
    bit = u8(block % 64)
    return
}

allocator_is_32k_free :: proc(a: ^Allocator($N), block: int) -> bool {
    idx, bit := allocator_get_32k(block)
    return ((a._32k[idx] >> bit) & 0b1) == 0
}

allocator_is_16k_free :: proc(a: ^Allocator($N), block: int) -> bool {
    idx, bit := allocator_get_16k(block)
    return ((a._16k[idx] >> bit) & 0b1) == 0
}

allocator_is_8k_free :: proc(a: ^Allocator($N), block: int) -> bool {
    idx, bit := allocator_get_8k(block)
    return ((a._8k[idx] >> bit) & 0b1) == 0
}

allocator_is_page_free :: proc(a: ^Allocator($N), block: int) -> bool {
    idx, bit := allocator_get_4k(block)
    return ((a._4k[idx] >> bit) & 0b1) == 0
}

allocator_set_32k_used :: proc(a: ^Allocator($N), block: int) {
    idx, bit := allocator_get_32k(block)
    a._32k[idx] |= 1 << bit
    a._16k[]
}

allocator_calculate_required_blocks :: proc(size: int) -> (_32k_blocks, _16k_blocks, _8k_blocks, pages: int) {
    rest := size

    _32k_blocks := rest / (runtime.Kilobyte * 32)
    rest -= (runtime.Kilobyte * 32 * _32k_blocks)

    _16k_blocks := rest / (runtime.Kilobyte * 16)
    rest -= (runtime.Kilobyte * 16 * _16k_blocks)

    _8k_blocks := rest / (runtime.Kilobyte *  8)
    rest -= (runtime.Kilobyte * 8 * _8k_blocks)

    pages := size / (runtime.Kilobyte *  4)
    rest -= (runtime.Kilobyte * 4 * pages)
    if rest > 0 {
        pages += 1
    }

    return
}

// test 63k
allocator_alloc_page :: proc(a: ^Allocator($N), size: int) -> int {
    _32k_blocks, _16k_blocks, _8k_blocks, pages := allocator_calculate_required_blocks(size)

    ARR_LEN :: N / 64
    MAX_32K_BLOCKS :: N / 64 * 8

    switch {
    case _32k_blocks > 0:
        all_blocks: for i in 0..<MAX_32K_BLOCKS {
            if MAX_32K_BLOCKS-(i+_32k_blocks) < 0 {
                break
            }

            for b in 0..<_32k_blocks {
                if !allocator_is_32k_free(b) {
                    continue all_blocks
                }
            }

            i_16k := i*2
            for b in i_16k..<_16k_blocks+i_16k {
                if !allocator_is_16k_free(b) {
                    continue all_blocks
                }
            }

            i_8k := i*4
            for b in i_8k..<_8k_blocks+i_8k {
                if !allocator_is_8k_free(b) {
                    continue all_blocks
                }
            }

            i_page := i*8
            for p in i_page..<pages+i_page {
                if !allocator_is_page_free(p) {
                    continue all_blocks
                }
            }
        }

        return 0
    }

    return 0
}
