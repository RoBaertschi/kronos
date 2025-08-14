package kronos_limine

COMMON_MAGIC1 :: 0xc7b1dd30df4c8b88
COMMON_MAGIC2 :: 0x0a82e883a194f07b

FRAMEBUFFER_REQUEST :: [4]u64{ COMMON_MAGIC1, COMMON_MAGIC2, 0x9d5827dcd881dd75, 0xa3148604f6fab11b }

Framebuffer_Request :: struct {
    id:       [4]u64,
    revision: u64,
    response: ^Framebuffer_Response,
}

Framebuffer_Response :: struct {
    revision:          u64,
    framebuffer_count: u64,
    framebuffers:     [^]^Framebuffer,
}

Video_Mode :: struct {
    pitch, width, height: u64,
    bpp: u16,
    memory_model, red_mask_size, red_mask_shift, green_mask_size, green_mask_shift, blue_mask_size, blue_mask_shift: u8,
}

Framebuffer :: struct {
    address: rawptr,
    width, height, pitch: u64,
    bpp: u16,
    memory_model, red_mask_size, red_mask_shift, green_mask_size, green_mask_shift, blue_mask_size, blue_mask_shift: u8,
    _: [7]u8,
    edid: rawptr,

    // revision 1
    mode_count: u64,
    modes:      [^]^Video_Mode,
}

MEMMAP_REQUEST :: [4]u64{ COMMON_MAGIC1, COMMON_MAGIC2, 0x67cf3d9d378a806f, 0xe304acdfc50c3c62 }

Memmap_Request :: struct {
    id:       [4]u64,
    revision: u64,
    response: ^Memmap_Response,
}

Memmap_Response :: struct {
    revision:    u64,
    entry_count: u64,
    entries:     [^]^Memmap_Entry,
}

Memmap_Type :: enum u64 {
    Usable,
    Reserved,
    Acpi_Reclaimable,
    Acpi_Nvs,
    Bad_Memory,
    Bootloader_Reclaimable,
    Executable_And_Modules,
    Framebuffer,
}

Memmap_Entry :: struct {
    base:   uintptr,
    length: u64,
    type:   Memmap_Type,
}

@(export, link_section=".limine_requests_start")
requests_start_marker := [4]u64{0xf6b8f4b39de7d1ae, 0xfab91a6940fcb9cf, 0x785c6ed015d3e316, 0x181e920a7852b9d9}

@(export, link_section=".limine_requests_end")
requests_end_marker := [2]u64{0xadc0e0531bb10d03, 0x9572709f31764c62}

@(export, link_section=".limine_requests")
base_revision := [3]u64{ 0xf9562b2d5c95a6c8, 0x6a7b384944536bdc, 3 }

BASE_REVISION_SUPPORTED :: #force_inline proc "contextless"() -> bool {
    return base_revision[2] == 0
}

@(export, link_section=".limine_requests")
framebuffer_request := Framebuffer_Request{
    id       = FRAMEBUFFER_REQUEST,
    revision = 0,
}

@(export, link_section=".limine_requests")
memmap_request := Memmap_Request{
    id       = MEMMAP_REQUEST,
    revision = 0,
}
