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

offset, physical_base, virtual_base: uintptr

find_stack_memmap :: proc(stack_pointer: uintptr) -> (pos: uintptr, len: u64) {
    memmap := limine.memmap_request.response

    if memmap == nil {
        panic("No Memmap")
    }

    memmap_entries := memmap.entries[:memmap.entry_count]
    for entry in memmap_entries {
        if entry.type == .Bootloader_Reclaimable {
            if entry.base <= (stack_pointer - offset) && (stack_pointer - offset) <= entry.base + uintptr(entry.length) {
                fmt.wprintfln(sw.writer(), "Found stack in bootloader reclaimable memory at %p", rawptr(entry.base))
                return entry.base, entry.length
            }
        }
    }

    panic("Could not find the stack in the memmap")
}

print_current_paging :: proc() {
    cr3 := Cr3(cpu.get_cr3())
    pml4 := (^[512]cpu.Page_Map_Level_4_Entry)((cr3.base << 12) + offset)

    w := sw.writer()
    for pml4_entry, pml4_index in pml4 {
        if pml4_entry.present {
            fmt.wprintfln(w, "Start PML4 %X", pml4_index)
            pdp := (^[512]cpu.Page_Directory_Pointer_Entry)((uintptr(pml4_entry.address) << 12) + offset)

            for pdp_entry, pdp_index in pdp {
                if pdp_entry.present {
                    fmt.wprintfln(w, "Start PDP %X", pdp_index)

                    pd := (^[512]cpu.Page_Directory_Entry)((uintptr(pdp_entry.address) << 12) + offset)

                    for pd_entry, pd_index in pd {
                        if pd_entry.present {
                            fmt.wprintfln(w, "Start PD %X present=%v", pd_index, pd_entry.present)
                            pt := (^[512]cpu.Page_Table_Entry)((uintptr(pd_entry.address) << 12) + offset)

                            for page in pt {
                                fmt.wprintf(w, "%s", page.present ? "#" : ".")
                                // fmt.wprintfln(w, "Page %X present=%v", page_index, page.present)
                            }
                            fmt.wprintfln(w, "\nEnd PD %X", pd_index)
                        }
                    }
                    fmt.wprintfln(w, "End PD %X", pdp_index)
                }
            }
            fmt.wprintfln(w, "End PML4 %X", pml4_index)
        }
    }
}

init_minimal :: proc(stack_pointer: uintptr) {
    stack_pointer := stack_pointer
    stack_pointer -= 64 * runtime.Kilobyte

    w := sw.writer()
    offset = limine.hhdm_request.response.offset
    physical_base = limine.executable_address_request.response.physical_base
    virtual_base = limine.executable_address_request.response.virtual_base

    print_current_paging()

    physical_stack, physical_stack_length := find_stack_memmap(stack_pointer)
    stack_pointer = physical_stack + offset

    assert(physical_stack_length <= PAGE_SIZE * 512)

    if limine.executable_address_request.response == nil || limine.hhdm_request.response == nil {
        panic("Missing required limine responses")
    }
    fmt.wprintfln(w, "pb=%p vb=%p o=%p", rawptr(physical_base), rawptr(virtual_base), rawptr(limine.hhdm_request.response.offset))

    fmt.wprintfln(sw.writer(), "Mapping from %p to %p", rawptr(uintptr(virtual_base)), rawptr(((physical_base >> 12) + uintptr(0)) << 12))
    for i in 0..<512 {
        map_pages(((physical_base >> 12) + uintptr(i)) << 12,
            Canonical_Address(virtual_base + uintptr(i * PAGE_SIZE)),
            &page_directory_pointer_entries,
            &page_directory_entries,
            &page_table_entries,
        )
    }

    fmt.wprintfln(sw.writer(), "Mapping from %p to %p", rawptr(stack_pointer), rawptr((physical_stack >> 12) << 12))
    for i in 0..<min(512, physical_stack_length / PAGE_SIZE) {
        map_pages(
            ((physical_stack >> 12) + uintptr(i)) << 12,
            Canonical_Address(((stack_pointer >> 12) + uintptr(i)) << 12),
            &stack_page_directory_pointer_entries,
            &stack_page_directory_entries,
            &stack_page_table_entries,
        )
    }

    reload_cr3()

    fmt.wprintfln(w, "Initalized paging from %p to %p", rawptr(virtual_base), rawptr(physical_base))
}

map_pages :: proc(physical_address: uintptr, virtual_address: Canonical_Address,
    dir_ptr_entries: ^[512]cpu.Page_Directory_Pointer_Entry,
    dir_entries: ^[512]cpu.Page_Directory_Entry,
    table_entries: ^[512]cpu.Page_Table_Entry,
) {
    dir_ptr_entries := dir_ptr_entries
    dir_entries := dir_entries
    table_entries := table_entries

    pml4_entry := &page_map_level_4_entries[virtual_address.page_map_level_4_offset]
    if !pml4_entry.present {
        pml4_entry^ = {
            address = (uintptr(&dir_ptr_entries[0]) - virtual_base + physical_base) >> 12,
            present = true,
            read_write = true,
        }
    } else {
        dir_ptr_entries = cast(^[512]cpu.Page_Directory_Pointer_Entry)((pml4_entry.address << 12) - physical_base + virtual_base)
    }

    pdp_entry := &dir_ptr_entries[virtual_address.page_directory_pointer_offset]
    if !pdp_entry.present {
        pdp_entry^ = {
            address = (uintptr(&dir_entries[0]) - virtual_base + physical_base) >> 12,
            present = true,
            read_write = true,
        }
    } else {
        dir_entries = cast(^[512]cpu.Page_Directory_Entry)((pdp_entry.address << 12) - physical_base + virtual_base)
    }

    pd_entry := &dir_entries[virtual_address.page_directory_offset]
    if !pd_entry.present {
        pd_entry^ = {
            address = (uintptr(&table_entries[0]) - virtual_base + physical_base) >> 12,
            present = true,
            read_write = true,
        }
    } else {
        table_entries = cast(^[512]cpu.Page_Table_Entry)((pd_entry.address << 12) - physical_base + virtual_base)
    }

    fmt.wprintfln(sw.writer(), "%v -> %p", virtual_address, rawptr(physical_address))
    table_entries[virtual_address.page_table_offset] = {
        address    = physical_base >> 12,
        present    = true,
        read_write = true,
    }
}

reload_cr3 :: proc() {
    if limine.executable_address_request.response == nil || limine.hhdm_request.response == nil {
        panic("Missing hhdm or executable_address_request response from limine")
    }

    cr3 := Cr3(cpu.get_cr3())
    cr3.base = (uintptr(&page_map_level_4_entries[0]) - virtual_base + physical_base) >> 12
    cpu.magic_breakpoint()
    cpu.set_cr3(u64(cr3))
}

bootstrap_pages :: proc(physical_address: uintptr, pages: int) -> uintptr {
    assert(physical_address % 4096 == 0)
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
