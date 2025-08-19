cpu x86-64
bits 64

section .bss

global page_map_level_4_entries
global page_directory_pointer_entries
global page_directory_entries
global page_table_entries

global bootstrap_page_table_entries

global stack_page_directory_pointer_entries
global stack_page_directory_entries
global stack_page_table_entries

ALIGN 0x1000
page_map_level_4_entries:
    times 512 resq 1

ALIGN 0x1000
page_directory_pointer_entries:
    times 512 resq 1

ALIGN 0x1000
page_directory_entries:
    times 512 resq 1

ALIGN 0x1000
page_table_entries:
    times 512 resq 1

ALIGN 0x1000
bootstrap_page_table_entries:
    times 512 resq 1

ALIGN 0x1000
stack_page_directory_pointer_entries:
    times 512 resq 1

ALIGN 0x1000
stack_page_directory_entries:
    times 512 resq 1

ALIGN 0x1000
stack_page_table_entries:
    times 512 resq 1
