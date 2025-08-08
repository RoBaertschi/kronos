odin build kernel -out:bin/kernel   \
    -build-mode:obj                 \
    -target:freestanding_amd64_sysv \
    -no-crt                         \
    -no-thread-local                \
    -no-entry-point                 \
    -reloc-mode:pic                 \
    -disable-red-zone               \
    -default-to-nil-allocator       \
    -foreign-error-procedures       \
    -vet                            \
    -strict-style

nasm kernel/kernel.asm -o bin/kernel.o -f elf64

ld bin/*.o -o bin/kernel.elf \
    -m elf_x86_64            \
    -nostdlib                \
    -static                  \
    -pie                     \
    --no-dynamic-linker      \
    -z text                  \
    -z max-page-size=0x1000  \
    -T kernel/link.ld 
