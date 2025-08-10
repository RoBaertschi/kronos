#+build freestanding
#+private
package runtime

import "kernel:serial"

// TODO(bill): reimplement `os.write`
_stderr_write :: proc "contextless" (data: []byte) -> (int, _OS_Errno) {
    serial.write(data)
	return len(data), 0
}
