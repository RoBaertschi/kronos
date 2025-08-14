package kronos_allocator_physical

import "base:runtime"

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

allocator_set_32k :: proc(a: ^Allocator($N), block: int, used: bool) {
    used := u8(1 if used else 0)

    idx, bit := allocator_get_32k(block)
    a._32k[idx] |= used << bit

    allocator_set_16k(a, block * 2 + 0, used)
    allocator_set_16k(a, block * 2 + 1, used)
}

allocator_set_16k :: proc(a: ^Allocator($N), block: int, used: bool) {
    used := u8(1 if used else 0)

    idx, bit := allocator_get_16k(block)
    a._16k[idx] |= used << bit

    allocator_set_8k(a, block * 2 + 0, used)
    allocator_set_8k(a, block * 2 + 1, used)
}

allocator_set_8k :: proc(a: ^Allocator($N), block: int, used: bool) {
    used := u8(1 if used else 0)

    idx, bit := allocator_get_8k(block)
    a._8k[idx] |= used << bit

    allocator_set_4k(a, block * 2 + 0, used)
    allocator_set_4k(a, block * 2 + 1, used)
}

allocator_set_4k :: proc(a: ^Allocator($N), block: int, used: bool) {
    used := u8(1 if used else 0)

    idx, bit := allocator_get_4k(block)
    a._4k[idx] |= used << bit
}

allocator_calculate_required_blocks :: proc(size: int) -> (_32k_blocks, _16k_blocks, _8k_blocks, pages: int) {
    rest := size

    _32k_blocks = rest / (runtime.Kilobyte * 32)
    rest -= (runtime.Kilobyte * 32 * _32k_blocks)

    _16k_blocks = rest / (runtime.Kilobyte * 16)
    rest -= (runtime.Kilobyte * 16 * _16k_blocks)

    _8k_blocks = rest / (runtime.Kilobyte *  8)
    rest -= (runtime.Kilobyte * 8 * _8k_blocks)

    pages = size / (runtime.Kilobyte *  4)
    rest -= (runtime.Kilobyte * 4 * pages)
    if rest > 0 {
        if pages == 0 {
            pages += 1
        } else if _8k_blocks == 0 {
            _8k_blocks += 1
        } else if _16k_blocks == 0 {
            _16k_blocks += 1
        } else {
            _32k_blocks += 1
        }
    }

    return
}

allocator_alloc_pages :: proc(a: ^Allocator($N), size: int) -> (int, runtime.Allocator_Error) {
    _32k_blocks, _16k_blocks, _8k_blocks, pages := allocator_calculate_required_blocks(size)

    ARR_LEN :: N / 64
    MAX_32K_BLOCKS :: N / 64 * 8
    MAX_16K_BLOCKS :: N / 64 * 4
    MAX_8K_BLOCKS :: N / 64 * 2
    MAX_PAGES :: N / 64

    switch {
    case _32k_blocks > 0:
        all_blocks: for i in 0..<MAX_32K_BLOCKS {
            if MAX_32K_BLOCKS-(i+_32k_blocks) < 0 {
                break
            }

            for b in i..<_32k_blocks+i {
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

            for b in 0..<_32k_blocks {
                allocator_set_32k(a, b+i)
            }

            for b in 0..<_16k_blocks {
                allocator_set_16k(a, b+i_16k)
            }

            for b in 0..<_8k_blocks {
                allocator_set_8k(a, b+i_8k)
            }

            for b in 0..<pages {
                allocator_set_4k(a, b+i_page)
            }

            return i * i_page,  nil
        }
    case _16k_blocks > 0:
        all_blocks: for i in 0..<MAX_16K_BLOCKS {
            if MAX_16K_BLOCKS-(i+_16k_blocks) < 0 {
                break
            }

            for b in i..<_16k_blocks+i {
                if !allocator_is_16k_free(b) {
                    continue all_blocks
                }
            }

            i_8k := i*2
            for b in i_8k..<_8k_blocks+i_8k {
                if !allocator_is_8k_free(b) {
                    continue all_blocks
                }
            }

            i_page := i*4
            for p in i_page..<pages+i_page {
                if !allocator_is_page_free(p) {
                    continue all_blocks
                }
            }

            for b in 0..<_16k_blocks {
                allocator_set_16k(a, b+i)
            }

            for b in 0..<_8k_blocks {
                allocator_set_8k(a, b+i_8k)
            }

            for b in 0..<pages {
                allocator_set_4k(a, b+i_page)
            }

            return i * i_page, nil
        }
    case _8k_blocks > 0:
        all_blocks: for i in 0..<MAX_8K_BLOCKS {
            if MAX_8K_BLOCKS-(i+_8k_blocks) < 0 {
                break
            }

            for b in i..<_8k_blocks+i {
                if !allocator_is_8k_free(b) {
                    continue all_blocks
                }
            }

            i_page := i*2
            for p in i_page..<pages+i_page {
                if !allocator_is_page_free(p) {
                    continue all_blocks
                }
            }


            for b in 0..<_8k_blocks {
                allocator_set_8k(a, b+i_8k)
            }

            for b in 0..<pages {
                allocator_set_4k(a, b+i_page)
            }

            return i * i_page, nil
        }
    case pages > 0:
        all_blocks: for i in 0..<MAX_PAGES {
            if MAX_PAGES-(i+pages) < 0 {
                break
            }

            for p in i_page..<pages+i_page {
                if !allocator_is_page_free(p) {
                    continue all_blocks
                }
            }

            for b in 0..<pages {
                allocator_set_4k(a, b+i)
            }

            return i, nil
        }
    }

    return -1, .Out_Of_Memory
}

allocator_free_pages :: proc(a: ^Allocator($N), page: int, size: int) -> (int, runtime.Allocator_Error) {
    _32k_blocks, _16k_blocks, _8k_blocks, pages := allocator_calculate_required_blocks(size)
}
