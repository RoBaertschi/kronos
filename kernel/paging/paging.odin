package kronos_paging

import "base:runtime"

import "kernel:serial"
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
}

Canonical_Address :: bit_field uintptr {
    physical_page_offset:          u16 | 12,
    page_table_offset:             u16 | 9,
    page_directory_offset:         u16 | 9,
    page_directory_pointer_offset: u16 | 9,
    page_map_level_4_offset:       u16 | 9,
    sign_extend:                   u16 | 16,
}

init_minimal :: proc() {
    if limine.executable_address_request.response == nil || limine.hhdm_request.response == nil {
        return
    }

    offset := limine.hhdm_request.response.offset

    physical_base := limine.executable_address_request.response.physical_base
    virtual_base := limine.executable_address_request.response.virtual_base

    canonical_virtual_base := Canonical_Address(virtual_base)
    page_map_level_4_entries[canonical_virtual_base.page_map_level_4_offset] = {
        address = uintptr(&page_directory_pointer_entries[0]) >> 12,
        present = true,
    }
    page_directory_pointer_entries[canonical_virtual_base.page_directory_pointer_offset] = {
        address = uintptr(&page_directory_entries[0]) >> 12,
        present = true,
    }

    page_directory_entries[canonical_virtual_base.page_directory_offset] = {
        address = uintptr(&page_table_entries[0]) >> 12,
        present = true,
    }

    for &entry, i in page_table_entries {
        entry = {
            address =    (physical_base >> 12) + uintptr(i),
            present =    true,
            read_write = true,
        }
    }

    cpu.set_cr3(u64(uintptr(&page_map_level_4_entries[0]) - offset) & 0x000FFFFFF000)
    serial.write_string("Initalized paging!")
}

bootstrap_pages :: proc(physical_address: uintptr, pages: int) -> uintptr {
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

    runtime.print_string("Reserved ")
    runtime.print_int(pages)
    runtime.print_string(" pages for bootstraping at ")
    runtime.print_uintptr(physical_address)
    runtime.print_string("\n")
    return virtual_base
}
