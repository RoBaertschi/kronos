set -e

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

step "==> Building Kernel"

run odin build kernel -out:bin/kernel   \
    -build-mode:obj                 \
    -target:freestanding_amd64_sysv \
    -no-crt                         \
    -no-thread-local                \
    -no-entry-point                 \
    -reloc-mode:pic                 \
    -disable-red-zone               \
    -default-to-nil-allocator       \
    -vet                            \
    -strict-style
    # -foreign-error-procedures       \

run nasm kernel/kernel.asm -o bin/kernel.o -f elf64

run ld bin/*.o -o bin/kronos.elf \
    -m elf_x86_64            \
    -nostdlib                \
    -static                  \
    -pie                     \
    --no-dynamic-linker      \
    -z text                  \
    -z max-page-size=0x1000  \
    -T kernel/link.ld

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
