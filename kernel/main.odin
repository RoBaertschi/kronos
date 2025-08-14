package kronos_kernel

import "base:runtime"

import "kernel:limine"
import "kernel:cpu"
import "kernel:idt"
import "kernel:serial"

import "core:fmt"
import "core:io"

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

gdt := [5]u64{}

gdt_init :: proc() {
    cpu.encode_gdt_entry(&gdt[0], {})
    cpu.encode_gdt_entry(&gdt[1], { limit = 0xFFFFF, access_byte = 0x9A, flags = 0xA })
    cpu.encode_gdt_entry(&gdt[2], { limit = 0xFFFFF, access_byte = 0x92, flags = 0xC })
    cpu.encode_gdt_entry(&gdt[3], { limit = 0xFFFFF, access_byte = 0xFA, flags = 0xA })
    cpu.encode_gdt_entry(&gdt[4], { limit = 0xFFFFF, access_byte = 0xF2, flags = 0xC })
    cpu.set_gdt(len(gdt)*size_of(gdt[0]) - 1, uintptr(&gdt))
}

print_memmap :: proc(w: io.Writer) {
    response := limine.memmap_request.response
    if response == nil {
        runtime.print_string("No Memmap\n")
    } else {
        entries := response.entries[:response.entry_count]

        for entry, i in entries {
            fmt.wprintfln(w, "% 2d: % 15d - % 15d [len % 15d] = %v",
                i,
                entry.base,
                entry.base + uintptr(entry.length),
                entry.length,
                entry.type,
            )
        }
    }
}

serial_stream_proc : io.Stream_Proc : proc(stream_data: rawptr, mode: io.Stream_Mode, p: []byte, offset: i64, whence: io.Seek_From) -> (n: i64, err: io.Error) {
    _ = stream_data
    _ = offset
    _ = whence

    #partial switch mode {
    case .Write:
        serial.write(p)
        n = i64(len(p))
        return
    case .Query:
        n = transmute(i64)io.Stream_Mode_Set{.Query, .Write}
        return
    case:
        return
    }
}

@(export, link_name="_start")
kmain :: proc "sysv" () {
    cpu.enable_sse()

    context = runtime.default_context()
    if serial.init() {
        serial.write_string("Hello World!\n")
    }

    #force_no_inline runtime._startup_runtime()

    writer := io.Writer{
        procedure = serial_stream_proc,
    }

    gdt_init()
    idt.init()
    print_memmap(writer)


    if !limine.BASE_REVISION_SUPPORTED() {
        quit()
    }

    if limine.framebuffer_request.response == nil || limine.framebuffer_request.response.framebuffer_count < 1 {
        quit()
    }

    framebuffer := limine.framebuffer_request.response.framebuffers[0]

    for i in 0..<100 {
        fb_ptr := cast([^]u32) framebuffer.address
        fb_ptr[u64(i) * (framebuffer.pitch / 4) + u64(i)] = 0xffffff
    }

    panic("Oh no!")
    // quit()
}
