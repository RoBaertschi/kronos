#!/bin/bash
set -e

if [[ -n "$1" ]]; then

    case "$1" in
        test) TESTING=true;;
        *)    TESTING=false;;
    esac
else
    TESTING=false
fi

function run() {
    echo "* $@"
    $@
}

function step() {
    echo -e "\033[32m$1\033[0m"
}

step "==> Cleaning old Kernel"
rm -rfv bin
mkdir -pv bin

step "==> Setting up environment"
run export ODIN_ROOT="$(pwd)/kernel/odin-rt"

step "==> Building Kernel"

# TODO(robin): Switch to another build mode for automatic assembly compilation
run odinl build kernel -out:bin/kernel   \
    -debug                          \
    -collection:kernel=kernel       \
    -build-mode:obj                 \
    -target:freestanding_amd64_sysv \
    -no-crt                         \
    -no-thread-local                \
    -no-entry-point                 \
    -reloc-mode:pic                 \
    -disable-red-zone               \
    -default-to-nil-allocator       \
    -vet                            \
    -print-linker-flags             \
    -define:KRONOS_TESTING=$TESTING \
    -strict-style
    # -foreign-error-procedures       \

run nasm kernel/cpu/cpu.asm -o bin/kronos-cpu.asm.o -f elf64 -g
run nasm kernel/serial/serial.asm -o bin/kronos-serial.asm.o -f elf64 -g
run nasm kernel/idt/idt.asm -o bin/kronos-idt.asm.o -f elf64 -g
run nasm kernel/paging/paging.asm -o bin/kronos-paging.asm.o -f elf64 -g

run ld bin/*.o -o bin/kronos.elf \
    -m elf_x86_64            \
    -nostdlib                \
    -static                  \
    -pie                     \
    --no-dynamic-linker      \
    -z text                  \
    -z max-page-size=0x1000  \
    -T kernel/link.ld

nm -n --defined-only iso_root/boot/kronos \
| awk '/ [tTdDbBrR] / && $3 !~ /^\./ { print $1, $3 }' \
> bin/kronos.sym

step "==> Building limine"
make -C limine

step "==> Creating ISO root"
mkdir -pv iso_root/boot/limine
cp -v ./bin/kronos.elf iso_root/boot/kronos
cp -v res/limine.conf limine/{limine-bios.sys,limine-bios-cd.bin,limine-uefi-cd.bin} iso_root/boot/limine/

mkdir -p iso_root/EFI/BOOT
cp -v limine/BOOTX64.EFI iso_root/EFI/BOOT
cp -v limine/BOOTIA32.EFI iso_root/EFI/BOOT

step "==> Creating ISO"
xorriso -as mkisofs -R -r -J -b boot/limine/limine-bios-cd.bin         \
        -no-emul-boot -boot-load-size 4 -boot-info-table -hfsplus      \
        -apm-block-size 2048 --efi-boot boot/limine/limine-uefi-cd.bin \
        -efi-boot-part --efi-boot-image --protective-msdos-label       \
        iso_root -o image.iso

if [[ ! -f ovmf/ovmf-code-x86_64.fd ]]; then
    step "==> Downloading OVMF"
    mkdir -p ovmf
    curl -#Lo ovmf/ovmf-code-x86_64.fd https://github.com/osdev0/edk2-ovmf-nightly/releases/latest/download/ovmf-code-x86_64.fd
fi

echo -e "\033[31mRun ./run-uefi.sh to run using the UEFI\033[0m"
