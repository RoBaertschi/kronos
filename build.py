#!/usr/bin/env python3

import argparse
import os
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path
from typing import List, Tuple

class Config:
    BIN_DIR = Path("bin")
    ISO_ROOT = Path("iso_root")
    KERNEL_DIR = Path("kernel")
    LIMINE_DIR = Path("limine")
    OVMF_DIR = Path("ovmf")
    RES_DIR = Path("res")
    
    ODIN_ARGS = [
        "-debug", "-collection:kernel=kernel", "-build-mode:obj",
        "-target:freestanding_amd64_sysv", "-no-crt", "-no-thread-local",
        "-no-entry-point", "-reloc-mode:pic", "-disable-red-zone",
        "-default-to-nil-allocator", "-vet", "-print-linker-flags", "-strict-style"
    ]
    
    NASM_ARGS = ["-f", "elf64", "-g"]
    
    LINKER_ARGS = [
        "-m", "elf_x86_64", "-nostdlib", "-static", "-pie",
        "--no-dynamic-linker", "-z", "text", "-z", "max-page-size=0x1000"
    ]
    
    ASM_FILES = [
        "entry_point", "cpu/cpu", "serial/serial", "idt/idt", "paging/paging"
    ]
    
    FILE_COPIES = [
        ("res/limine.conf", "boot/limine"),
        ("limine/limine-bios.sys", "boot/limine"),
        ("limine/limine-bios-cd.bin", "boot/limine"),
        ("limine/limine-uefi-cd.bin", "boot/limine"),
        ("limine/BOOTX64.EFI", "EFI/BOOT"),
        ("limine/BOOTIA32.EFI", "EFI/BOOT")
    ]
    
    OVMF_URL = "https://github.com/osdev0/edk2-ovmf-nightly/releases/latest/download/ovmf-code-x86_64.fd"

TESTING = False

def run(cmd: List[str] | str, shell: bool = False, silent: bool = False) -> None:
    if not silent:
        cmd_str = " ".join(cmd) if isinstance(cmd, list) else cmd
        print(f"* {cmd_str}")
    
    try:
        subprocess.run(cmd, shell=shell, check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error: Command failed with exit code {e.returncode}")
        sys.exit(1)

def step(message: str) -> None:
    print(f"\033[32m{message}\033[0m")

def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)

def copy_if_exists(src: str | Path, dst: str | Path) -> None:
    src_path = Path(src)
    if src_path.exists():
        shutil.copy(src_path, dst)

class Builder:
    def __init__(self, testing: bool = False, debug: bool = False):
        self.testing = testing
        self.debug = debug
    
    def clean(self) -> None:
        step("==> Cleaning old Kernel")
        shutil.rmtree(Config.BIN_DIR, ignore_errors=True)
        Config.BIN_DIR.mkdir()
    
    def setup_environment(self) -> None:
        step("==> Setting up environment")
        odin_root = Path.cwd() / Config.KERNEL_DIR / "odin-rt"
        os.environ["ODIN_ROOT"] = str(odin_root)
        print(f"* export ODIN_ROOT={odin_root}")
    
    def build_kernel(self) -> None:
        step("==> Building Kernel")
        cmd = [
            "odin", "build", str(Config.KERNEL_DIR),
            f"-out:{Config.BIN_DIR}/kernel",
            f"-define:KRONOS_TESTING={str(self.testing).lower()}"
        ] + Config.ODIN_ARGS
        run(cmd)
    
    def build_assembly(self) -> None:
        step("==> Building Assembly Files")
        for asm_file in Config.ASM_FILES:
            src = Config.KERNEL_DIR / f"{asm_file}.asm"
            dst = Config.BIN_DIR / f"kronos-{asm_file.replace('/', '-')}.asm.o"
            run(["nasm", str(src), "-o", str(dst)] + Config.NASM_ARGS)
    
    def link_kernel(self) -> None:
        step("==> Linking Kernel")
        cmd = (f"ld {Config.BIN_DIR}/*.o -o {Config.BIN_DIR}/kronos.elf "
               f"-T {Config.KERNEL_DIR}/link.ld " + " ".join(Config.LINKER_ARGS))
        run(cmd, shell=True)
    
    def generate_symbols(self) -> None:
        step("==> Generating Symbols")
        
        nm_result = subprocess.run(
            ["nm", "-n", "--defined-only", f"{Config.ISO_ROOT}/boot/kronos"],
            capture_output=True, text=True, check=True
        )
        
        symbols = []
        for line in nm_result.stdout.strip().split('\n'):
            if not line:
                continue
            
            parts = line.split()
            if len(parts) >= 3:
                addr, symbol_type, symbol_name = parts[0], parts[1], parts[2]
                if symbol_type in 'tTdDbBrR' and not symbol_name.startswith('.'):
                    symbols.append(f"{addr} {symbol_name}")
        
        with open(Config.BIN_DIR / "kronos.sym", 'w') as f:
            f.write('\n'.join(symbols) + '\n')
    
    def build_limine(self) -> None:
        step("==> Building limine")
        run(["make", "-C", str(Config.LIMINE_DIR)])
    
    def create_iso_structure(self) -> None:
        step("==> Creating ISO root")
        
        ensure_dir(Config.ISO_ROOT / "boot" / "limine")
        ensure_dir(Config.ISO_ROOT / "EFI" / "BOOT")
        
        shutil.copy(Config.BIN_DIR / "kronos.elf", Config.ISO_ROOT / "boot" / "kronos")
        
        for src, dst in Config.FILE_COPIES:
            copy_if_exists(src, Config.ISO_ROOT / dst)
    
    def create_iso(self) -> None:
        step("==> Creating ISO")
        cmd = [
            "xorriso", "-as", "mkisofs", "-R", "-r", "-J",
            "-b", "boot/limine/limine-bios-cd.bin", "-no-emul-boot",
            "-boot-load-size", "4", "-boot-info-table", "-hfsplus",
            "-apm-block-size", "2048", "--efi-boot", "boot/limine/limine-uefi-cd.bin",
            "-efi-boot-part", "--efi-boot-image", "--protective-msdos-label",
            str(Config.ISO_ROOT), "-o", "image.iso"
        ]
        run(cmd)
    
    def download_ovmf(self) -> None:
        ovmf_file = Config.OVMF_DIR / "ovmf-code-x86_64.fd"
        if not ovmf_file.exists():
            step("==> Downloading OVMF")
            ensure_dir(Config.OVMF_DIR)
            urllib.request.urlretrieve(Config.OVMF_URL, ovmf_file)
            print(f"* Downloaded OVMF to {ovmf_file}")
    
    def build_all(self) -> None:
        self.setup_environment()
        self.build_kernel()
        self.build_assembly()
        self.link_kernel()
        self.generate_symbols()
        self.build_limine()
        self.create_iso_structure()
        self.create_iso()
        self.download_ovmf()
        print("\033[31mBuild complete! Use 'run' action to start UEFI\033[0m")
    
    def run_uefi(self) -> None:
        step("==> Running UEFI")
        
        qemu_cmd = [
            "qemu-system-x86_64",
            "-M", "q35",
            "-cdrom", "image.iso",
            "-boot", "d",
            "-m", "2G"
        ]
        
        if self.debug:
            qemu_cmd.extend(["-s", "-S"])
        
        if self.testing:
            qemu_cmd.extend(["-nographic", "-serial", "mon:stdio"])
        else:
            qemu_cmd.extend(["-serial", "stdio"])
        
        run(qemu_cmd)

def main():
    parser = argparse.ArgumentParser(description="Kronos OS Build System")
    parser.add_argument("action", choices=["build", "clean", "run"], 
                       help="Action to perform")
    parser.add_argument("--test", action="store_true", 
                       help="Enable testing mode")
    parser.add_argument("--kernel-only", action="store_true",
                       help="Build only kernel components")
    parser.add_argument("--debug", action="store_true",
                       help="Run QEMU with debug flags (-s -S)")
    
    args = parser.parse_args()
    
    builder = Builder(testing=args.test, debug=args.debug)
    
    try:
        if args.action == "clean":
            builder.clean()
        elif args.action == "build":
            builder.clean()
            if args.kernel_only:
                builder.setup_environment()
                builder.build_kernel()
                builder.build_assembly()
                builder.link_kernel()
                builder.generate_symbols()
            else:
                builder.build_all()
        elif args.action == "run":
            if not Path("image.iso").exists():
                print("No image.iso found, building first...")
                builder.clean()
                builder.build_all()
            builder.run_uefi()
    except KeyboardInterrupt:
        print("\nInterrupted")
        sys.exit(1)

if __name__ == "__main__":
    main()