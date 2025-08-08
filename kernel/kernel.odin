package kronos_kernel

@require foreign import kernel "kernel.asm"

foreign kernel {
    halt_catch_fire :: proc "sysv"() -> ! ---
}

LIMINE_COMMON_MAGIC1 :: 0xc7b1dd30df4c8b88
LIMINE_COMMON_MAGIC2 :: 0x0a82e883a194f07b

LIMINE_FRAMEBUFFER_REQUEST :: [4]u64{ LIMINE_COMMON_MAGIC1, LIMINE_COMMON_MAGIC2, 0x9d5827dcd881dd75, 0xa3148604f6fab11b }

Limine_Video_Mode :: struct {
    pitch, width, height: u64,
    bpp: u16,
    memory_model, red_mask_size, red_mask_shift, green_mask_size, green_mask_shift, blue_mask_size, blue_mask_shift: u8,
}

Limine_Framebuffer :: struct {
    address: rawptr,
    width, height, pitch: u64,
    bpp: u16,
    memory_model, red_mask_size, red_mask_shift, green_mask_size, green_mask_shift, blue_mask_size, blue_mask_shift: u8,
    _: [7]u8,
    edid: rawptr,

    // revision 1
    mode_count: u64,
    modes:      [^]^Limine_Video_Mode,
}

Limine_Framebuffer_Response :: struct {
    revision:          u64,
    framebuffer_count: u64,
    framebuffers:     [^]^Limine_Framebuffer,
}

Limine_Framebuffer_Request :: struct {
    id:       [4]u64,
    revision: u64,
    response: ^Limine_Framebuffer_Response,
}

@(export, link_section=".limine_requests_start")
limine_requests_start_marker := [4]u64{0xf6b8f4b39de7d1ae, 0xfab91a6940fcb9cf, 0x785c6ed015d3e316, 0x181e920a7852b9d9}

@(export, link_section=".limine_requests_end")
limine_requests_end_marker := [2]u64{0xadc0e0531bb10d03, 0x9572709f31764c62}

@(export, link_section=".limine_requests")
limine_base_revision := [3]u64{ 0xf9562b2d5c95a6c8, 0x6a7b384944536bdc, 3 }

@(export, link_section=".limine_requests")
framebuffer_request := Limine_Framebuffer_Request{
    id       = LIMINE_FRAMEBUFFER_REQUEST,
    revision = 0,
}

LIMINE_BASE_REVISION_SUPPORTED :: #force_inline proc "contextless"() -> bool {
    return limine_base_revision[2] == 0
}

@(export, link_name="_start")
kmain :: proc "sysv" () {
    if !LIMINE_BASE_REVISION_SUPPORTED() {
        halt_catch_fire()
    }

    if framebuffer_request.response == nil || framebuffer_request.response.framebuffer_count < 1 {
        halt_catch_fire()
    }

    framebuffer := framebuffer_request.response.framebuffers[0]

    for i in 0..<100 {
        fb_ptr := cast([^]u32) framebuffer.address
        fb_ptr[u64(i) * (framebuffer.pitch / 4) + u64(i)] = 0xffffff
    }

    halt_catch_fire()
}
