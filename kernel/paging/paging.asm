cpu x86-64
bits 64

section .bss

global page_map_level_4_entries
global page_directory_pointer_entries
global page_directory_entries
global page_table_entries
global bootstrap_page_table_entries

; HHDM page tables for 4KB pages - need full hierarchy
global hhdm_page_directory_pointer_entries
global hhdm_page_directory_entries
global hhdm_page_table_entries

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

; HHDM page tables for 4KB mapping
ALIGN 0x1000
hhdm_page_directory_pointer_entries:
    times 512 resq 1

ALIGN 0x1000  
hhdm_page_directory_entries:
    times 1024 resq 1    ; 2GB worth of PD entries (4 x 512)

ALIGN 0x1000
hhdm_page_table_entries:
    times 524288 resq 1  ; 2GB worth of 4KB pages (1024 * 512)
