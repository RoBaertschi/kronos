package kronos_utils

import "base:intrinsics"

get_bit :: proc(number: $T, bit: u8) -> bool where intrinsics.type_is_integer(T) {
    return (number >> bit) & 0b1 != 0
}

set_bit :: proc(number: $T, bit: u8, value: bool) -> T where intrinsics.type_is_integer(T) {
    return (number & ~(T(1) << bit)) | ((1 if value else 0) << bit)
}
