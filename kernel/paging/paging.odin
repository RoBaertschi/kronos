package kronos_paging

import "base:runtime"

import "core:fmt"

import sw "kernel:serial/writer"
import "kernel:cpu"
import "kernel:limine"

PAGE_SIZE :: 4 * runtime.Kilobyte

@require foreign import paging "paging.asm"

foreign paging {
    page_map_level_4_entries: [512]cpu.Page_Map_Level_4_Entry
    page_directory_pointer_entries: [512]cpu.Page_Directory_Pointer_Entry
    page_directory_entries: [512]cpu.Page_Directory_Entry
    page_table_entries: [512]cpu.Page_Table_Entry

    bootstrap_page_table_entries: [512]cpu.Page_Table_Entry

    stack_page_directory_pointer_entries: [512]cpu.Page_Directory_Pointer_Entry
    stack_page_directory_entries: [512]cpu.Page_Directory_Entry
    stack_page_table_entries: [512]cpu.Page_Table_Entry
}

Canonical_Address :: bit_field uintptr {
    physical_page_offset:          u16 | 12,
    page_table_offset:             u16 | 9,
    page_directory_offset:         u16 | 9,
    page_directory_pointer_offset: u16 | 9,
    page_map_level_4_offset:       u16 | 9,
    sign_extend:                   u16 | 16,
}

Cr3 :: bit_field u64 {
    _: u8 | 3,

    pwt: bool | 1,
    pcd: bool | 1,

    _: u8 | 7,

    base: uintptr | 40,

    _: u16 | 12,
}

init_minimal :: proc(stack_pointer: uintptr) {
    if limine.executable_address_request.response == nil || limine.hhdm_request.response == nil {
        panic("Missing required limine responses")
    }

    offset := limine.hhdm_request.response.offset

    physical_base := limine.executable_address_request.response.physical_base
    virtual_base := limine.executable_address_request.response.virtual_base

    canonical_stack_base := Canonical_Address(stack_pointer)
    canonical_virtual_base := Canonical_Address(virtual_base)
    fmt.wprintfln(sw.writer(), "pb=%p vb=%p o=%p", rawptr(physical_base), rawptr(virtual_base), rawptr(limine.hhdm_request.response.offset))

    for i in 0..<512 {
        map_pages((physical_base >> 12) + uintptr(i),
            Canonical_Address(virtual_base + uintptr(i)),
            
        )
    }

    for &entry, i in page_table_entries {
        entry = {
            address =    (physical_base >> 12) + uintptr(i),
            present =    true,
            read_write = true,
        }
    }

    reload_cr3()

    w := sw.writer()
    fmt.wprintln(w, "Initalized paging from %p to %p", rawptr(virtual_base), rawptr(physical_base))
}

map_pages :: proc(physical_address: uintptr, virtual_address: Canonical_Address,
    dir_ptr_entries: ^[512]cpu.Page_Directory_Pointer_Entry,
    dir_entries: ^[512]cpu.Page_Directory_Entry,
    table_entries: ^[512]cpu.Page_Table_Entry,
) {
    fmt.wprintfln(sw.writer(), "Mapping from %p to %p", rawptr(uintptr(virtual_address)), rawptr(physical_address))

    physical_base := limine.executable_address_request.response.physical_base
    virtual_base := limine.executable_address_request.response.virtual_base

    pml4_entry := &page_map_level_4_entries[virtual_address.page_map_level_4_offset]
    if !pml4_entry.present {
        pml4_entry^ = {
            address = (uintptr(&dir_ptr_entries[0]) - virtual_base + physical_base) >> 12,
            present = true,
        }
    }

    pdp_entry := &dir_ptr_entries[virtual_address.page_directory_pointer_offset]
    if !pdp_entry.present {
        pdp_entry^ = {
            address = (uintptr(&dir_entries[0]) - virtual_base + physical_base) >> 12,
            present = true,
        }
    }

    pd_entry := &dir_entries[virtual_address.page_directory_offset]
    if !pd_entry.present {
        pd_entry^ = {
            address = (uintptr(&table_entries[0]) - virtual_base + physical_base) >> 12,
            present = true,
        }
    }

    page_table_entries[virtual_address.page_table_offset] = {
        address    = physical_base >> 12,
        present    = true,
        read_write = true,
    }
}

reload_cr3 :: proc() {
    if limine.executable_address_request.response == nil || limine.hhdm_request.response == nil {
        panic("Missing hhdm or executable_address_request response from limine")
    }

    virtual_base := limine.executable_address_request.response.virtual_base
    physical_base := limine.executable_address_request.response.physical_base
    cr3 := Cr3(0)
    cr3.base = (uintptr(&page_map_level_4_entries[0]) - virtual_base + physical_base) >> 12
    cpu.magic_breakpoint()
    cpu.set_cr3(u64(cr3))
}

bootstrap_pages :: proc(physical_address: uintptr, pages: int) -> uintptr {
    assert(physical_address % 4096 == 0)
    virtual_base := limine.executable_address_request.response.virtual_base + (512 * PAGE_SIZE)
    canonical_virtual_base := Canonical_Address(virtual_base)

    assert(pages <= 512)

    page_directory_entries[canonical_virtual_base.page_directory_offset] = {
        address = uintptr(&bootstrap_page_table_entries[0]) >> 12,
        present = true,
    }

    for i in 0..<pages {
        bootstrap_page_table_entries[i] = {
            address =    (physical_address >> 12) + uintptr(i),
            present =    true,
            read_write = true,
        }
    }

    for i in pages..<512 {
        bootstrap_page_table_entries[i] = {
            present = false,
        }
    }

    reload_cr3()
    w := sw.writer()

    fmt.wprintfln(w, "Reserved %d pages for bootstraping from %p to %p", pages, rawptr(virtual_base), rawptr(physical_address))
    return virtual_base
}
