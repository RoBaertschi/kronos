set -x

TESTING=false
EXTRA_ARGS=""
for arg in "$@"; do
    case "$arg" in
        "-debug") EXTRA_ARGS="-s -S $EXTRA_ARGS";;
        "-test") EXTRA_ARGS="-nographic $EXTRA_ARGS"; TESTING=true;;
        *) ;;
    esac
done

if $TESTING; then
    EXTRA_ARGS="-serial mon:stdio $EXTRA_ARGS"
else
    EXTRA_ARGS="-serial stdio $EXTRA_ARGS"
fi


qemu-system-x86_64          \
    $EXTRA_ARGS             \
    -M q35                  \
    -cdrom image.iso        \
    -boot d                 \
    -d int,cpu_reset        \
    -D /tmp/qemu.log        \
    -action panic=pause     \
    -action reboot=shutdown \
    -action shutdown=pause  \
    -m 2G
