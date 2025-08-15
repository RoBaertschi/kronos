package kronos_serial_writer

import "kernel:serial"

import "core:io"

serial_stream_proc : io.Stream_Proc : proc(stream_data: rawptr, mode: io.Stream_Mode, p: []byte, offset: i64, whence: io.Seek_From) -> (n: i64, err: io.Error) {
    _ = stream_data
    _ = offset
    _ = whence

    #partial switch mode {
    case .Write:
        serial.write(p)
        n = i64(len(p))
        return
    case .Query:
        n = transmute(i64)io.Stream_Mode_Set{.Query, .Write}
        return
    case:
        return
    }
}

writer :: proc() -> io.Writer {
    return {
        procedure = serial_stream_proc,
    }
}
