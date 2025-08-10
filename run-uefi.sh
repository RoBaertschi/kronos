qemu-system-x86_64 \
    -M q35 \
    -cdrom image.iso \
    -boot d \
    -serial stdio \
    -m 2G
