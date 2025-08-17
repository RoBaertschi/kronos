package kronos_testing

import serial_writer "kernel:serial/writer"
import "core:fmt"
import "core:io"

TESTING :: #config(KRONOS_TESTING, false)

T :: struct {
    error_count: int,
    new_line:    bool,
    writer:      io.Writer,
}

Test_Proc :: proc(^T)

Test :: struct {
    name:   string,
    system: string,
    p:      Test_Proc,
}

run_test :: proc(test: Test) {
    w := serial_writer.writer()

    fmt.wprintf(w, "Running %s.%s ...", test.system, test.name)
    t: T
    t.writer = w
    test.p(&t)

    if t.error_count > 0 {
        fmt.wprintln(w, "FAILED")
    } else {
        fmt.wprintln(w, "OK")
    }
}

_new_line :: proc(t: ^T) {
    if !t.new_line {
        io.write_rune(t.writer, '\n')
        t.new_line = true
    }
}

expect_value :: proc(t: ^T, value, expected: $T, loc := #caller_location) -> bool {
    if value != expected {
        _new_line(t)
        fmt.wprintfln(t.writer, "ASSERTION FAILED %v: %v != %v", loc, value, expected)
        t.error_count += 1
        return false
    }
    return true
}

expect :: proc(t: ^T, condition: bool, expr := #caller_expression(condition), loc := #caller_location) -> bool {
    if !condition {
        _new_line(t)
        fmt.wprintfln(t.writer, "ASSERTION FAILED %v: %v", loc, expr)
        t.error_count += 1
        return false
    }
    return true
}
