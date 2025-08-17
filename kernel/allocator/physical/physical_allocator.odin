package kronos_allocator_physical

import "base:runtime"

import "core:io"

import "kernel:utils"

// PAGE_SIZE :: 4 * runtime.Kilobyte

// N = Pages
Allocator :: struct(N: int) \
    where (N % 64 == 0) && (N > 0) { // Ensure that the amount of pages fit nicely into u64's
    _4k:  [N / 64]u64, // 8 bytes
    _8k:  [N / 64]u32, // 4 bytes
    _16k: [N / 64]u16, // 2 bytes
    _32k: [N / 64]u8,  // 1 bytes

    base: uintptr,
}

write_allocator :: proc(w: io.Writer, a: Allocator($N)) {
    fmt.wprintf(w, "Allocator($N=%d){{\n", N)
    fmt.wprintln(w, "    _4k = [")
    for b in a._4k {
        fmt.wprintfln(w, "        %0#64b", b)
    }
    fmt.wprintln(w, "    ],")

    fmt.wprintln(w, "    _8k = [")
    for b in a._8k {
        fmt.wprintfln(w, "        %#32b", b)
    }
    fmt.wprintln(w, "    ],")

    fmt.wprintln(w, "    _16k = [")
    for b in a._16k {
        fmt.wprintfln(w, "        %#16b", b)
    }
    fmt.wprintln(w, "    ],")

    fmt.wprintln(w, "    _32k = [")
    for b in a._32k {
        fmt.wprintfln(w, "        %#8b", b)
    }
    fmt.wprintln(w, "    ],")
    fmt.wprintf(w, "    base = %v,\n}\n", a.base)
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

allocator_is_32k_free :: proc(a: Allocator($N), block: int) -> bool {
    idx, bit := allocator_get_32k(block)
    return ((a._32k[idx] >> bit) & 0b1) == 0
}

allocator_is_16k_free :: proc(a: Allocator($N), block: int) -> bool {
    idx, bit := allocator_get_16k(block)
    return ((a._16k[idx] >> bit) & 0b1) == 0
}

allocator_is_8k_free :: proc(a: Allocator($N), block: int) -> bool {
    idx, bit := allocator_get_8k(block)
    return ((a._8k[idx] >> bit) & 0b1) == 0
}

allocator_is_page_free :: proc(a: Allocator($N), block: int) -> bool {
    idx, bit := allocator_get_4k(block)
    return ((a._4k[idx] >> bit) & 0b1) == 0
}

allocator_set_32k :: proc(a: ^Allocator($N), block: int, used: bool) {
    idx, bit := allocator_get_32k(block)
    a._32k[idx] = utils.set_bit(a._32k[idx], bit, used)

    allocator_set_16k(a, block * 2 + 0, used)
    allocator_set_16k(a, block * 2 + 1, used)
}

allocator_set_16k :: proc(a: ^Allocator($N), block: int, used: bool) {
    idx, bit := allocator_get_16k(block)
    a._16k[idx] = utils.set_bit(a._16k[idx], bit, used)

    allocator_set_8k(a, block * 2 + 0, used)
    allocator_set_8k(a, block * 2 + 1, used)
}

allocator_set_8k :: proc(a: ^Allocator($N), block: int, used: bool) {
    idx, bit := allocator_get_8k(block)
    a._8k[idx] = utils.set_bit(a._8k[idx], bit, used)

    allocator_set_4k(a, block * 2 + 0, used)
    allocator_set_4k(a, block * 2 + 1, used)
}

allocator_set_4k :: proc(a: ^Allocator($N), block: int, used: bool) {
    idx, bit := allocator_get_4k(block)
    a._4k[idx] = utils.set_bit(a._4k[idx], bit, used)
}

allocator_get_16k_offset :: proc(_32k_blocks: int) -> int {
    return _32k_blocks * 2
}

allocator_get_8k_offset :: proc(_32k_blocks, _16k_blocks: int) -> int {
    return _32k_blocks * 4 + _16k_blocks * 2
}

allocator_get_page_offset :: proc(_32k_blocks, _16k_blocks, _8k_blocks: int) -> int {
    return _32k_blocks * 8 + _16k_blocks * 4 + _8k_blocks * 2
}

allocator_has_allocation :: proc(a: Allocator($N), page: int, size: int) -> (has: bool) {
    page := page
    _32k_blocks, _16k_blocks, _8k_blocks, pages := allocator_calculate_required_blocks(size)
    assert(allocator_check_blocks_alignment(page, _32k_blocks, _16k_blocks, _8k_blocks))
    at_32k, at_16k, at_8k := allocator_page_to_blocks(page)
    at_16k += allocator_get_16k_offset(_32k_blocks)
    at_8k += allocator_get_8k_offset(_32k_blocks, _16k_blocks)
    page += allocator_get_page_offset(_32k_blocks, _16k_blocks, _8k_blocks)

    for b in 0..<_32k_blocks {
        (!allocator_is_32k_free(a, b + at_32k)) or_return
    }

    for b in 0..<_16k_blocks {
        (!allocator_is_16k_free(a, b + at_16k)) or_return
    }

    for b in 0..<_8k_blocks {
        (!allocator_is_8k_free(a, b + at_8k)) or_return
    }

    for b in 0..<pages {
        (!allocator_is_page_free(a, b + page)) or_return
    }

    return true
}

allocator_is_free :: proc(a: Allocator($N), page: int, size: int) -> (has: bool) {
    page := page
    _32k_blocks, _16k_blocks, _8k_blocks, pages := allocator_calculate_required_blocks(size)
    assert(allocator_check_blocks_alignment(page, _32k_blocks, _16k_blocks, _8k_blocks))
    at_32k, at_16k, at_8k := allocator_page_to_blocks(page)
    at_16k += allocator_get_16k_offset(_32k_blocks)
    at_8k  += allocator_get_8k_offset(_32k_blocks, _16k_blocks)
    page += allocator_get_page_offset(_32k_blocks, _16k_blocks, _8k_blocks)

    for b in 0..<_32k_blocks {
        allocator_is_32k_free(a, b + at_32k) or_return
    }

    for b in 0..<_16k_blocks {
        allocator_is_16k_free(a, b + at_16k) or_return
    }

    for b in 0..<_8k_blocks {
        allocator_is_8k_free(a, b + at_8k) or_return
    }

    for b in 0..<pages {
        allocator_is_page_free(a, b + page) or_return
    }

    return true
}

allocator_page_to_blocks :: proc(page: int) -> (at_32k, at_16k, at_8k: int) {
    at_32k = page / 8
    at_16k = page / 4
    at_8k  = page / 2

    return
}

// Check if page is correctly aligned
allocator_check_block_size_alignment :: proc(page: int, size: int) -> (ok: bool) {
    _32k_blocks, _16k_blocks, _8k_blocks, _ := allocator_calculate_required_blocks(size)
    return allocator_check_blocks_alignment(page, _32k_blocks, _16k_blocks, _8k_blocks)
}

allocator_check_blocks_alignment :: proc(page: int, _32k_blocks, _16k_blocks, _8k_blocks: int) -> (ok: bool) {
    if _32k_blocks > 0 {
        (page % 8 == 0) or_return
    }

    if _16k_blocks > 0 {
        (page % 4 == 0) or_return
    }

    if _8k_blocks > 0 {
        (page % 2 == 0) or_return
    }

    return true
}

allocator_calculate_required_blocks :: proc(size: int) -> (_32k_blocks, _16k_blocks, _8k_blocks, pages: int) {
    rest := size

    _32k_blocks = rest / (runtime.Kilobyte * 32)
    rest -= (runtime.Kilobyte * 32 * _32k_blocks)

    _16k_blocks = rest / (runtime.Kilobyte * 16)
    rest -= (runtime.Kilobyte * 16 * _16k_blocks)

    _8k_blocks = rest / (runtime.Kilobyte * 8)
    rest -= (runtime.Kilobyte * 8 * _8k_blocks)

    pages = rest / (runtime.Kilobyte * 4)
    rest -= (runtime.Kilobyte * 4 * pages)

    if rest > 0 {
        pages += 1
    }
    if pages == 2 {
        pages = 0
        _8k_blocks += 1
    }

    if _8k_blocks == 2 {
        _8k_blocks = 0
        _16k_blocks += 1
    }

    if _16k_blocks == 2 {
        _16k_blocks = 0
        _32k_blocks += 1
    }

    return
}

allocator_alloc :: proc(a: ^Allocator($N), size: int) -> (rawptr, runtime.Allocator_Error) {
    page := allocator_alloc_pages(a, size) or_return
    return a.base + uintptr(page * PAGE_SIZE), nil
}

// IMPORTANT: size is in bytes, not pages
allocator_alloc_pages :: proc(a: ^Allocator($N), size: int) -> (int, runtime.Allocator_Error) {
    _32k_blocks, _16k_blocks, _8k_blocks, pages := allocator_calculate_required_blocks(size)

    ARR_LEN :: N / 64
    MAX_32K_BLOCKS :: N / 64 * 8
    MAX_16K_BLOCKS :: N / 64 * 4
    MAX_8K_BLOCKS :: N / 64 * 2
    MAX_PAGES :: N / 64

    switch {
    case _32k_blocks > 0:
        all_32k_blocks: for i in 0..<MAX_32K_BLOCKS {
            if MAX_32K_BLOCKS-(i+_32k_blocks) < 0 {
                break
            }

            for b in i..<_32k_blocks+i {
                if !allocator_is_32k_free(a^, b) {
                    continue all_32k_blocks
                }
            }

            i_16k := i*2
            for b in i_16k..<_16k_blocks+i_16k {
                if !allocator_is_16k_free(a^, b) {
                    continue all_32k_blocks
                }
            }

            i_8k := i*4
            for b in i_8k..<_8k_blocks+i_8k {
                if !allocator_is_8k_free(a^, b) {
                    continue all_32k_blocks
                }
            }

            i_page := i*8
            for p in i_page..<pages+i_page {
                if !allocator_is_page_free(a^, p) {
                    continue all_32k_blocks
                }
            }

            for b in 0..<_32k_blocks {
                allocator_set_32k(a, b+i, true)
            }

            for b in 0..<_16k_blocks {
                allocator_set_16k(a, b+i_16k, true)
            }

            for b in 0..<_8k_blocks {
                allocator_set_8k(a, b+i_8k, true)
            }

            for b in 0..<pages {
                allocator_set_4k(a, b+i_page, true)
            }

            return i * i_page,  nil
        }
    case _16k_blocks > 0:
        all_16k_blocks: for i in 0..<MAX_16K_BLOCKS {
            if MAX_16K_BLOCKS-(i+_16k_blocks) < 0 {
                break
            }

            for b in i..<_16k_blocks+i {
                if !allocator_is_16k_free(a^, b) {
                    continue all_16k_blocks
                }
            }

            i_8k := i*2
            for b in i_8k..<_8k_blocks+i_8k {
                if !allocator_is_8k_free(a^, b) {
                    continue all_16k_blocks
                }
            }

            i_page := i*4
            for p in i_page..<pages+i_page {
                if !allocator_is_page_free(a^, p) {
                    continue all_16k_blocks
                }
            }

            for b in 0..<_16k_blocks {
                allocator_set_16k(a, b+i, true)
            }

            for b in 0..<_8k_blocks {
                allocator_set_8k(a, b+i_8k, true)
            }

            for b in 0..<pages {
                allocator_set_4k(a, b+i_page, true)
            }

            return i * i_page, nil
        }
    case _8k_blocks > 0:
        all_8k_blocks: for i in 0..<MAX_8K_BLOCKS {
            if MAX_8K_BLOCKS-(i+_8k_blocks) < 0 {
                break
            }

            for b in i..<_8k_blocks+i {
                if !allocator_is_8k_free(a^, b) {
                    continue all_8k_blocks
                }
            }

            i_page := i*2
            for p in i_page..<pages+i_page {
                if !allocator_is_page_free(a^, p) {
                    continue all_8k_blocks
                }
            }


            for b in 0..<_8k_blocks {
                allocator_set_8k(a, b+i, true)
            }

            for b in 0..<pages {
                allocator_set_4k(a, b+i_page, true)
            }

            return i * i_page, nil
        }
    case pages > 0:
        all_pages: for i in 0..<MAX_PAGES {
            if MAX_PAGES-(i+pages) < 0 {
                break
            }

            for p in i..<pages+i {
                if !allocator_is_page_free(a^, p) {
                    continue all_pages
                }
            }

            for b in 0..<pages {
                allocator_set_4k(a, b+i, true)
            }

            return i, nil
        }
    }

    return -1, .Out_Of_Memory
}

allocator_free :: proc(a: ^Allocator($N), ptr: rawptr, size: int) -> (err: runtime.Allocator_Error) {
    if uintptr(ptr) < a.base || (uintptr(ptr) - a.base) % PAGE_SIZE != 0 {
        return .Invalid_Pointer
    }
    page := int(uintptr(ptr) - a.base) / PAGE_SIZE
    return allocator_free_pages(a, page, size)
}

allocator_free_pages :: proc(a: ^Allocator($N), page: int, size: int) -> (err: runtime.Allocator_Error) {
    page := page
    _32k_blocks, _16k_blocks, _8k_blocks, pages := allocator_calculate_required_blocks(size)
    if !allocator_check_blocks_alignment(page, _32k_blocks, _16k_blocks, _8k_blocks) {
        return .Invalid_Pointer
    }

    page_32k, page_16k, page_8k := allocator_page_to_blocks(page)
    page_16k += allocator_get_16k_offset(_32k_blocks)
    page_8k  += allocator_get_8k_offset(_32k_blocks, _16k_blocks)
    page     += allocator_get_page_offset(_32k_blocks, _16k_blocks, _8k_blocks)

    for b in 0..<_32k_blocks {
        allocator_set_32k(a, b + page_32k, false)
    }

    for b in 0..<_16k_blocks {
        allocator_set_16k(a, b + page_16k, false)
    }

    for b in 0..<_8k_blocks {
        allocator_set_8k(a, b + page_8k, false)
    }

    for b in 0..<pages {
        allocator_set_4k(a, b + page, false)
    }

    return
}

// Tests

import "kernel:testing"

when testing.TESTING {
    run_tests :: proc() {
        testing.run_test({ name = "test_free", system = "kronos_allocator_physical", p = test_free })
        testing.run_test({ name = "test_allocate", system = "kronos_allocator_physical", p = test_allocate })
        testing.run_test({ name = "test_calculate_pages", system = "kronos_allocator_physical", p = test_calculate_pages })
        testing.run_test({ name = "test_calculate_size", system = "kronos_allocator_physical", p = test_calculate_size })
        testing.run_test({ name = "test_physical_allocator2", system = "kronos_allocator_physical", p = test_physical_allocator2 })
        testing.run_test({ name = "test_blocks", system = "kronos_allocator_physical", p = test_blocks })
        testing.run_test({ name = "test_set_functions", system = "kronos_allocator_physical", p = test_set_functions })
        testing.run_test({ name = "test_allocations", system = "kronos_allocator_physical", p = test_allocations })
    }

    test_blocks :: proc(t: ^testing.T) {
        _32k_blocks, _16k_blocks, _8k_blocks, pages := allocator_calculate_required_blocks(runtime.Kilobyte * 4)
        testing.expect_value(t, pages, 1)
        testing.expect_value(t, _8k_blocks, 0)
        testing.expect_value(t, _16k_blocks, 0)
        testing.expect_value(t, _32k_blocks, 0)

        _32k_blocks, _16k_blocks, _8k_blocks, pages = allocator_calculate_required_blocks(runtime.Kilobyte * 8)
        testing.expect_value(t, pages, 0)
        testing.expect_value(t, _8k_blocks, 1)
        testing.expect_value(t, _16k_blocks, 0)
        testing.expect_value(t, _32k_blocks, 0)

        _32k_blocks, _16k_blocks, _8k_blocks, pages = allocator_calculate_required_blocks(runtime.Kilobyte * 16)
        testing.expect_value(t, pages, 0)
        testing.expect_value(t, _8k_blocks, 0)
        testing.expect_value(t, _16k_blocks, 1)
        testing.expect_value(t, _32k_blocks, 0)

        _32k_blocks, _16k_blocks, _8k_blocks, pages = allocator_calculate_required_blocks(runtime.Kilobyte * 32)
        testing.expect_value(t, pages, 0)
        testing.expect_value(t, _8k_blocks, 0)
        testing.expect_value(t, _16k_blocks, 0)
        testing.expect_value(t, _32k_blocks, 1)

        _32k_blocks, _16k_blocks, _8k_blocks, pages = allocator_calculate_required_blocks(runtime.Kilobyte * 64)
        testing.expect_value(t, pages, 0)
        testing.expect_value(t, _8k_blocks, 0)
        testing.expect_value(t, _16k_blocks, 0)
        testing.expect_value(t, _32k_blocks, 2)

        _32k_blocks, _16k_blocks, _8k_blocks, pages = allocator_calculate_required_blocks(runtime.Kilobyte * 36)
        testing.expect_value(t, pages, 1)
        testing.expect_value(t, _8k_blocks, 0)
        testing.expect_value(t, _16k_blocks, 0)
        testing.expect_value(t, _32k_blocks, 1)

        _32k_blocks, _16k_blocks, _8k_blocks, pages = allocator_calculate_required_blocks(runtime.Kilobyte * ((32 * 1) + (16 * 1) + (8 * 1) + (4 * 1)))
        testing.expect_value(t, pages, 1)
        testing.expect_value(t, _8k_blocks, 1)
        testing.expect_value(t, _16k_blocks, 1)
        testing.expect_value(t, _32k_blocks, 1)

        _32k_blocks, _16k_blocks, _8k_blocks, pages = allocator_calculate_required_blocks((runtime.Kilobyte * ((32 * 1) + (16 * 1) + (8 * 1) + (4 * 1))) + 2323)
        testing.expect_value(t, pages, 0)
        testing.expect_value(t, _8k_blocks, 0)
        testing.expect_value(t, _16k_blocks, 0)
        testing.expect_value(t, _32k_blocks, 2)
    }

    test_set_functions :: proc(t: ^testing.T) {
        a := Allocator(64){}

        testing.expect(t, allocator_is_free(a, 0, PAGE_SIZE * 64))
        allocator_set_32k(&a, 0, true)
        testing.expect(t, !allocator_is_free(a, 0, runtime.Kilobyte * 32))
        testing.expect(t, allocator_has_allocation(a, 0, runtime.Kilobyte * 32))
    }

    test_allocations :: proc(t: ^testing.T) {
        a := Allocator(64){
            base = 0x1000,
        }

        testing.expect(t, allocator_is_free(a, 0, PAGE_SIZE))

        page, err := allocator_alloc_pages(&a, PAGE_SIZE)
        testing.expect_value(t, err, runtime.Allocator_Error.None)
        testing.expect_value(t, page, 0)
        testing.expect(t, allocator_has_allocation(a, page, PAGE_SIZE))

        err = allocator_free_pages(&a, page, PAGE_SIZE)
        testing.expect_value(t, err, runtime.Allocator_Error.None)
        testing.expect(t, allocator_is_free(a, page, PAGE_SIZE))
    }
}
