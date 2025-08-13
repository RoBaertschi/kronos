package kronos_utils

import "base:runtime"
import "base:intrinsics"

Type_Info :: runtime.Type_Info

Type_Info_Named                  :: runtime.Type_Info_Named
Type_Info_Integer                :: runtime.Type_Info_Integer
Type_Info_Rune                   :: runtime.Type_Info_Rune
Type_Info_Float                  :: runtime.Type_Info_Float
Type_Info_Complex                :: runtime.Type_Info_Complex
Type_Info_Quaternion             :: runtime.Type_Info_Quaternion
Type_Info_String                 :: runtime.Type_Info_String
Type_Info_Boolean                :: runtime.Type_Info_Boolean
Type_Info_Any                    :: runtime.Type_Info_Any
Type_Info_Type_Id                :: runtime.Type_Info_Type_Id
Type_Info_Pointer                :: runtime.Type_Info_Pointer
Type_Info_Multi_Pointer          :: runtime.Type_Info_Multi_Pointer
Type_Info_Procedure              :: runtime.Type_Info_Procedure
Type_Info_Array                  :: runtime.Type_Info_Array
Type_Info_Enumerated_Array       :: runtime.Type_Info_Enumerated_Array
Type_Info_Dynamic_Array          :: runtime.Type_Info_Dynamic_Array
Type_Info_Slice                  :: runtime.Type_Info_Slice
Type_Info_Parameters             :: runtime.Type_Info_Parameters
Type_Info_Struct                 :: runtime.Type_Info_Struct
Type_Info_Union                  :: runtime.Type_Info_Union
Type_Info_Enum                   :: runtime.Type_Info_Enum
Type_Info_Map                    :: runtime.Type_Info_Map
Type_Info_Bit_Set                :: runtime.Type_Info_Bit_Set
Type_Info_Simd_Vector            :: runtime.Type_Info_Simd_Vector
Type_Info_Matrix                 :: runtime.Type_Info_Matrix
Type_Info_Soa_Pointer            :: runtime.Type_Info_Soa_Pointer
Type_Info_Bit_Field              :: runtime.Type_Info_Bit_Field

Type_Info_Enum_Value :: runtime.Type_Info_Enum_Value


Type_Kind :: enum {
    Invalid,

    Named,
    Integer,
    Rune,
    Float,
    Complex,
    Quaternion,
    String,
    Boolean,
    Any,
    Type_Id,
    Pointer,
    Multi_Pointer,
    Procedure,
    Array,
    Enumerated_Array,
    Dynamic_Array,
    Slice,
    Parameters,
    Struct,
    Union,
    Enum,
    Map,
    Bit_Set,
    Simd_Vector,
    Matrix,
    Soa_Pointer,
    Bit_Field,
}

// Reflect related stuff

@(require_results)
reflect_enum_string :: proc "contextless" (a: any) -> string {
    if a == nil { return "" }
    ti := runtime.type_info_base(type_info_of(a.id))
    if e, ok := ti.variant.(runtime.Type_Info_Enum); ok {
        v, _ := reflect_as_i64(a)
        for value, i in e.values {
            if value == Type_Info_Enum_Value(v) {
                return e.names[i]
            }
        }
    } else {
        panic_contextless("expected an enum to reflect.enum_string")
    }

    return ""
}


/*
Returns whether the value given has a defined name in the enum type.
*/
@(require_results)
reflect_enum_value_has_name :: proc "contextless" (value: $T) -> bool where intrinsics.type_is_enum(T) {
    when len(T) == cap(T) {
        return value >= min(T) && value <= max(T)
    } else {
        if value < min(T) || value > max(T) {
            return false
        }

        for valid_value in T {
            if valid_value == value {
                return true
            }
        }

        return false
    }
}

@(require_results)
reflect_as_i64 :: proc "contextless" (a: any) -> (value: i64, valid: bool) {
    if a == nil { return }
    a := a
    ti := runtime.type_info_core(type_info_of(a.id))
    a.id = ti.id

    #partial switch info in ti.variant {
    case Type_Info_Integer:
        valid = true
        switch v in a {
        case i8:      value = i64(v)
        case i16:     value = i64(v)
        case i32:     value = i64(v)
        case i64:     value =      v
        case i128:    value = i64(v)
        case int:     value = i64(v)

        case u8:      value = i64(v)
        case u16:     value = i64(v)
        case u32:     value = i64(v)
        case u64:     value = i64(v)
        case u128:    value = i64(v)
        case uint:    value = i64(v)
        case uintptr: value = i64(v)

        case u16le:   value = i64(v)
        case u32le:   value = i64(v)
        case u64le:   value = i64(v)
        case u128le:  value = i64(v)

        case i16le:   value = i64(v)
        case i32le:   value = i64(v)
        case i64le:   value = i64(v)
        case i128le:  value = i64(v)

        case u16be:   value = i64(v)
        case u32be:   value = i64(v)
        case u64be:   value = i64(v)
        case u128be:  value = i64(v)

        case i16be:   value = i64(v)
        case i32be:   value = i64(v)
        case i64be:   value = i64(v)
        case i128be:  value = i64(v)
        case: valid = false
        }

    case Type_Info_Rune:
        r := a.(rune)
        value = i64(r)
        valid = true

    case Type_Info_Float:
        valid = true
        switch v in a {
        case f32:   value = i64(v)
        case f64:   value = i64(v)
        case f32le: value = i64(v)
        case f64le: value = i64(v)
        case f32be: value = i64(v)
        case f64be: value = i64(v)
        case: valid = false
        }

    case Type_Info_Boolean:
        valid = true
        switch v in a {
        case bool: value = i64(v)
        case b8:   value = i64(v)
        case b16:  value = i64(v)
        case b32:  value = i64(v)
        case b64:  value = i64(v)
        case: valid = false
        }

    case Type_Info_Complex:
        switch v in a {
        case complex64:
            if imag(v) == 0 {
                value = i64(real(v))
                valid = true
            }
        case complex128:
            if imag(v) == 0 {
                value = i64(real(v))
                valid = true
            }
        }

    case Type_Info_Quaternion:
        switch v in a {
        case quaternion128:
            if imag(v) == 0 && jmag(v) == 0 && kmag(v) == 0 {
                value = i64(real(v))
                valid = true
            }
        case quaternion256:
            if imag(v) == 0 && jmag(v) == 0 && kmag(v) == 0 {
                value = i64(real(v))
                valid = true
            }
        }
    }

    return
}
