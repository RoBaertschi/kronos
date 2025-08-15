package kronos_utils

import "base:intrinsics"

set_bit :: proc(number: $T, bit: u8, value: bool) -> T where intrinsics.type_is_integer(T) {
    return (number & ~(T(1) << bit)) | ((1 if value else 0) << bit)
}
