package kronos_cpu

@require foreign import kernel "kernel.asm"

foreign kernel {
    halt_catch_fire :: proc "sysv"() -> ! ---
    enable_sse :: proc "sysv"() ---
}
