if [[ "$1" == "-debug" ]]; then
    EXTRA_ARGS="-s -S"
else
    EXTRA_ARGS=
fi


qemu-system-x86_64 \
    $EXTRA_ARGS \
    -M q35 \
    -cdrom image.iso \
    -boot d \
    -serial stdio \
    -m 2G
