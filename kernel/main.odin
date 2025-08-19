package kronos_kernel

import "base:runtime"

import "kernel:cpu"
import "kernel:idt"
import "kernel:gdt"
import "kernel:limine"
import "kernel:serial"
import "kernel:paging"
import "kernel:testing"
import serial_writer "kernel:serial/writer"
import pa "kernel:allocator/physical"
_ :: pa

import "core:io"
import "core:mem"
import "core:fmt"

quit :: proc() {
    #force_no_inline runtime._cleanup_runtime()
    cpu.halt_catch_fire()
}

// assertion_failure_proc :: proc(prefix, message: string, loc: runtime.Source_Code_Location) -> ! {
//     #force_no_inline runtime._cleanup_runtime()
//     assertion_contextless_failure_proc(prefix, message, loc)
// }
//
// assertion_contextless_failure_proc :: proc "contextless" (prefix, message: string, loc: runtime.Source_Code_Location) -> ! {
//     runtime.print_caller_location(loc)
//     runtime.print_string(" ")
//     runtime.print_string(prefix)
//     if len(message) > 0 {
//         runtime.print_string(": ")
//         runtime.print_string(message)
//     }
//
//     runtime.print_byte('\n')
//     halt_catch_fire()
// }

// finds the smallest memmap entry for initial use
find_first_ideal_memmap_entry :: proc() -> ^limine.Memmap_Entry {
    memmap := limine.memmap_request.response
    if memmap == nil {
        return nil
    } else {
        memmap_entries := memmap.entries[:memmap.entry_count]
        smallest_entry : ^limine.Memmap_Entry = nil
        for entry in memmap_entries {
            if entry.type == .Usable {
                if smallest_entry == nil || smallest_entry.length > entry.length {
                    smallest_entry = entry
                }
            }
        }
        return smallest_entry
    }
}

print_memmap :: proc(w: io.Writer) {
    response := limine.memmap_request.response
    if response == nil {
        runtime.print_string("No Memmap\n")
    } else {
        entries := response.entries[:response.entry_count]
        total_accessible_memory: u64
        total_reclaimable_memory: u64

        for entry, i in entries {
            fmt.wprintfln(w, "% 2d: % 15d - % 15d [len % 15d] = %v",
                i,
                entry.base,
                entry.base + uintptr(entry.length),
                entry.length,
                entry.type,
            )

            #partial switch entry.type {
            case .Usable: total_accessible_memory += entry.length
            case .Acpi_Reclaimable, .Bootloader_Reclaimable: total_reclaimable_memory += entry.length
            }
        }

        fmt.wprintfln(w, "%d bytes usable memory({0:M}), %d bytes reclaimable memory({1:M})", total_accessible_memory, total_reclaimable_memory)
    }
}

@(export, link_name="kmain")
kmain :: proc "sysv" (rsp: uintptr) {
    context = runtime.default_context()
    if serial.init() {
        serial.write_string("Hello World!\n")
    }

    #force_no_inline runtime._startup_runtime()

    writer := serial_writer.writer()

    gdt.init()
    idt.init()
    paging.init_minimal()

    print_memmap(writer)
    memmap_entry := find_first_ideal_memmap_entry()
    bootstrap_pages := paging.bootstrap_pages(memmap_entry.base, int(memmap_entry.length) / paging.PAGE_SIZE)

    pa_buffer_size := pa.get_required_backing_size_for_pages(int(memmap_entry.length) / paging.PAGE_SIZE)
    assert(pa_buffer_size < int(memmap_entry.length))
    pa_buffer := (cast([^]u8)bootstrap_pages)[:pa_buffer_size]
    mem.zero(raw_data(pa_buffer), len(pa_buffer))
    physical_allocator: pa.Physical_Allocator
    pa.init_physical_allocator(&physical_allocator, pa_buffer, bootstrap_pages)

    if !limine.BASE_REVISION_SUPPORTED() {
        quit()
    }

    when testing.TESTING {
        pa.run_tests()
        quit()
    } else {
        if limine.framebuffer_request.response == nil || limine.framebuffer_request.response.framebuffer_count < 1 {
            quit()
        }

        framebuffer := limine.framebuffer_request.response.framebuffers[0]

        for i in 0..<100 {
            fb_ptr := cast([^]u32) framebuffer.address
            fb_ptr[u64(i) * (framebuffer.pitch / 4) + u64(i)] = 0xffffff
        }

        panic("Oh no!")
    }
}
