package kronos_allocator_physical

import "base:runtime"
import "base:intrinsics"

import "core:io"
import "core:fmt"
import "core:mem"
import "core:math"

import "kernel:utils"
import sw "kernel:serial/writer"
_ :: sw

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

get_level_page_size :: proc(level: int) -> int {
    return int(math.pow2_f32(f32(level)))
}

get_bit_idx_in_bytes :: proc(i: int) -> (int, u8) {
    return i / 8, u8(i % 8)
}

get_bit_in_bytes :: proc(bytes: []byte, i: int, loc := #caller_location) -> bool {
    runtime.bounds_check_error_loc(loc, i, len(bytes) * 8)
    idx, bit := get_bit_idx_in_bytes(i)
    return ((bytes[idx] >> bit) & 0b1) != 0
}

set_bit_in_bytes :: proc(bytes: []byte, i: int, set: bool, loc := #caller_location) {
    runtime.bounds_check_error_loc(loc, i, len(bytes) * 8)
    idx, bit := get_bit_idx_in_bytes(i)
    bytes[idx] = utils.set_bit(bytes[idx], bit, set)
}

get_level_pos :: proc(a: Physical_Allocator, level: int, loc := #caller_location) -> int {
    runtime.bounds_check_error_loc(loc, level, a.levels)
    e := math.pow2_f32(f32(level))
    return int(f32(len(a.data) * 8) * (1 - 1 / e))
}

get_level_size :: proc(a: Physical_Allocator, level: int, loc := #caller_location) -> int {
    return (((len(a.data) / 2) * 8) / int(math.pow2_f32(f32(level))))
}

get_level_bounds :: proc(a: Physical_Allocator, level: int, loc := #caller_location) -> (start, end: int) {
    start = get_level_pos(a, level, loc)
    end = get_level_size(a, level, loc) + start
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

    io.write_string(w, "         all: ")

    root_level_start, root_level_end := get_level_bounds(a, 0)
    for i in root_level_start..<root_level_end {
        write_bit(w, get_bit_in_bytes(a.data, i))
    }
    io.write_rune(w, '\n')
    io.write_rune(w, '\n')

    for i in 0..<a.levels {
        start, end := get_level_bounds(a, i)

        fmt.wprintf(w, "% 3d..% 3d % 3d: ", start, end, i)
        for j in start..<end {
            write_bit(w, get_bit_in_bytes(a.data, j))

            for _ in 1..<math.pow2_f32(f32(i)) {
                io.write_rune(w, ' ')
            }
        }
        fmt.wprintfln(w, "% 4dKiB % 3d Pages", int(math.pow2_f32(f32(i))) * 4, int(math.pow2_f32(f32(i))))
    }
}

calculate_pages :: proc(a: Physical_Allocator, pages: int) -> (highest_pages: int, low_pages: u8) {
    rest := pages

    for i := a.levels-1; i >= 0 ; i -= 1 {
        page_count := int(math.pow2_f32(f32(i)))
        required := rest / page_count
        rest -= required * page_count

        // check if we are at the highest level of blocks (first iteration)
        if i == a.levels-1 {
            highest_pages = required
        } else {
            // fmt.wprintfln(sw.writer(), "pages = {} i = {} page_count = {} required = {} rest = {} highest_pages = {} low_pages = {:07b}", pages, i, page_count, required, rest, highest_pages, low_pages)
            // any smaller block than the highest cannot be more than 1, because that would be a bigger block from the level before
            ensure(required < 2)

            // move all the bits to the left, because we go through the loop in reverse, this should move the highest level up
            low_pages <<= 1
            low_pages += u8(required)
        }
    }
    ensure(rest == 0)

    return
}

is_page_block_free :: proc(a: Physical_Allocator, block: int, level: int, loc := #caller_location) -> (free: bool) {
    runtime.bounds_check_error_loc(loc, block, get_level_size(a, level))
    start := get_level_pos(a, level)

    (!get_bit_in_bytes(a.data, start + block))  or_return

    if level > 0 {
        is_page_block_free(a, block * 2 + 0, level - 1) or_return
        is_page_block_free(a, block * 2 + 1, level - 1) or_return
    }

    return true
}

set_page_block :: proc(a: ^Physical_Allocator, block: int, level: int, used: bool, loc := #caller_location) {
    runtime.bounds_check_error_loc(loc, block, get_level_size(a^, level, loc))
    start := get_level_pos(a^, level)
    set_bit_in_bytes(a.data, start + block, used)

    if level > 0 {
        set_page_block(a, block * 2 + 0, level - 1, used)
        set_page_block(a, block * 2 + 1, level - 1, used)
    }
}

calculate_size :: proc(a: Physical_Allocator, size: int) -> (highest_pages: int, low_pages: u8) {
    pages := size / PAGE_SIZE
    pages += size % PAGE_SIZE != 0 ? 1 : 0
    return calculate_pages(a, pages)
}

alloc_uninitalized_pages :: proc(a: ^Physical_Allocator, pages: int) -> (int, runtime.Allocator_Error) {
    highest_pages, low_pages := calculate_pages(a^, pages)

    if get_level_size(a^, a.levels-1) < highest_pages {
        return -1, .Out_Of_Memory
    }

    // the level where we gonna need the highest block
    allocation_level := a.levels-1 if highest_pages > 0 else int(8-intrinsics.count_leading_zeros(low_pages))-1
    allocation_level_page_count := int(math.pow2_f32(f32(allocation_level)))

    // iterate trough each block
    test_blocks: for i in 0..<get_level_size(a^, allocation_level) {
        for p in i..<i+highest_pages {
            // fmt.wprintln(sw.writer(), i, p, get_level_size(a^, allocation_level), allocation_level, highest_pages)
            if !is_page_block_free(a^, p, allocation_level) {
                // fmt.wprintln(sw.writer(), "page not free", p)
                continue test_blocks
            }
        }

        actual_level := allocation_level if allocation_level != a.levels-1 else allocation_level-1

        // in pages
        offset := allocation_level_page_count * (i+highest_pages)
        for level := actual_level; level >= 0; level -= 1 {
            if !utils.get_bit(low_pages, u8(level)) {
                continue
            }
            // fmt.wprintln(sw.writer(), "level =", level, "actual_level =", actual_level, "allocation_level =", allocation_level, "a.levels =", a.levels)

            page_count := int(math.pow2_f32(f32(level)))
            // if get_level_size(a^, level) <= offset / page_count {
            //     continue
            // }

            if !is_page_block_free(a^, offset / page_count, level) {
                // fmt.wprintln(sw.writer(), "page not free offset =", offset / page_count, "level =", level,
                //     "i =", i, "allocation_level_page_count =", allocation_level_page_count,
                //     "allocation_level =", allocation_level)
                continue test_blocks
            }
            offset += page_count
        }

        for p in i..<highest_pages+i {
            set_page_block(a, p, allocation_level, true)
        }

        offset = allocation_level_page_count * (i+highest_pages)
        for level := actual_level; level >= 0; level -= 1 {
            if utils.get_bit(low_pages, u8(level)) {
                page_count := int(math.pow2_f32(f32(level)))
                set_page_block(a, offset / page_count, level, true)
                offset += page_count
            }
        }

        return allocation_level_page_count * i, .None
    }

    return -1, .Out_Of_Memory
}

free_pages :: proc(a: ^Physical_Allocator, page: int, pages: int) -> (err: runtime.Allocator_Error) {
    highest_pages, low_pages := calculate_pages(a^, pages)
    allocation_level := a.levels-1
    if highest_pages <= 0 {
        allocation_level = int(8-intrinsics.count_leading_zeros(low_pages))-1
    }
    allocation_level_page_count := get_level_page_size(allocation_level)

    actual_level := allocation_level if allocation_level != a.levels-1 else allocation_level-1

    if page % allocation_level_page_count != 0 {
        return .Invalid_Pointer
    }

    highest_page_start := page / allocation_level_page_count
    if highest_pages > 0 {
        for p in highest_page_start..<highest_page_start+highest_pages {
            set_page_block(a, p, allocation_level, false)
        }
    }

    offset := allocation_level_page_count * (highest_page_start+highest_pages)
    for level := actual_level; level >= 0; level -= 1 {
        if utils.get_bit(low_pages, u8(level)) {
            page_count := get_level_page_size(level)
            set_page_block(a, offset / page_count, level, false)
            offset += page_count
        }
    }

    return
}

import "kernel:testing"

when testing.TESTING {
    test_free :: proc(t: ^testing.T) {
        buf: [8]u8
        a: Physical_Allocator
        init_physical_allocator(&a, buf[:], 0)

        Free_Test_Case :: struct {
            pages: int,
            level: int,
        }

        tests := [?]Free_Test_Case{
            { 16, a.levels-1 },
            { 8, a.levels-2 },
            { 9, a.levels-2 },
        }

        for test, i in tests {
            page, err := alloc_uninitalized_pages(&a, test.pages)
            testing.expect_value(t, page, 0)
            testing.expect_value(t, err, runtime.Allocator_Error.None)

            failed := false
            if !testing.expect_value(t, free_pages(&a, page, test.pages), runtime.Allocator_Error.None) {
                failed = true
            }
            if !testing.expect(t, is_page_block_free(a, 0, test.level)) {
                failed = true
            }
            if failed {
                testing._new_line(t)
                fmt.wprintfln(t.writer, "test_free: test %d failed\n%#v", i, test)
                write_allocator_usage(t.writer, a)
            }
        }

    }

    test_allocate :: proc(t: ^testing.T) {
        buf: [8]u8
        a: Physical_Allocator
        init_physical_allocator(&a, buf[:], 0)

        Allocate_Test_Case :: struct {
            reset: bool, // Reset the allocator
            pages: int,
            page:  int,
            err:   runtime.Allocator_Error,
        }

        tests := [?]Allocate_Test_Case{
            { pages = 4, page = 0, err = .None },
            { pages = 4, page = 4, err = .None },
            { pages = 8, page = 8, err = .None },
            { pages = 9, page = 16, err = .None },
            { pages = 8, page = -1, err = .Out_Of_Memory },
            { pages = 4, page = 28, err = .None },
            { pages = 2, page = 26, err = .None },
            { pages = 1, page = 25, err = .None },

            { reset = true, pages = 16, page = 0, err = .None },
            { pages = 16, page = 16, err = .None },
        }

        for test, i in tests {
            if test.reset {
                mem.zero(raw_data(buf[:]), len(buf))
            }
            page, err := alloc_uninitalized_pages(&a, test.pages)
            failed := false
            if !testing.expect_value(t, page, test.page) {
                failed = true
            }
            if !testing.expect_value(t, err, test.err) {
                failed = true
            }
            if failed {
                testing._new_line(t)
                fmt.wprintfln(t.writer, "test_allocate: test %d failed\n%#v", i, test)
                write_allocator_usage(t.writer, a)
            }
        }
    }

    test_calculate_pages :: proc(t: ^testing.T) {
        buf: [8]u8
        a: Physical_Allocator
        init_physical_allocator(&a, buf[:], 0)

        Pages_Test_Case :: struct {
            pages:         int,
            highest_pages: int,
            low_pages:     u8,
        }

        tests := [?]Pages_Test_Case{
            { pages = 1, highest_pages = 0, low_pages = 0b0001 },
            { pages = 4, highest_pages = 0, low_pages = 0b0100 },
            { pages = 6, highest_pages = 0, low_pages = 0b0110 },
            { pages = 7, highest_pages = 0, low_pages = 0b0111 },
            { pages = 15, highest_pages = 0, low_pages = 0b1111 },
            { pages = 16, highest_pages = 1, low_pages = 0b0000 },
            { pages = 17, highest_pages = 1, low_pages = 0b0001 },
            { pages = 31, highest_pages = 1, low_pages = 0b1111 },
        }

        for test in tests {
            highest_pages, low_pages := calculate_pages(a, test.pages)
            testing.expect_value(t, highest_pages, test.highest_pages)
            testing.expect_value(t, low_pages, test.low_pages)
        }
    }

    test_calculate_size :: proc(t: ^testing.T) {
        buf: [8]u8
        a: Physical_Allocator
        init_physical_allocator(&a, buf[:], 0)

        Size_Test_Case :: struct {
            size:          int,
            highest_pages: int,
            low_pages:     u8,
        }

        tests := [?]Size_Test_Case{
            { size = 4, highest_pages = 0, low_pages = 0b0001 },
            { size = PAGE_SIZE * 2, highest_pages = 0, low_pages = 0b0010 },
            { size = PAGE_SIZE * 18 + 1, highest_pages = 1, low_pages = 0b0011 },
            { size = PAGE_SIZE * 63 + 1, highest_pages = 4, low_pages = 0b0000 },
            { size = PAGE_SIZE * 64, highest_pages = 4, low_pages = 0b0000 },
            { size = PAGE_SIZE * 64 + 1, highest_pages = 4, low_pages = 0b0001 },
        }

        for test in tests {
            highest_pages, low_pages := calculate_size(a, test.size)
            testing.expect_value(t, highest_pages, test.highest_pages)
            testing.expect_value(t, low_pages, test.low_pages)
        }
    }
}
