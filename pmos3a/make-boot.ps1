$ErrorActionPreference = 'Stop'
$d = $PSScriptRoot; $o = "$d\out"; $llvm = 'C:\Program Files\LLVM\bin'
$cf = @('--target=aarch64-none-elf', '-O2', '-ffreestanding', '-nostdlib', '-fno-pic', '-mgeneral-regs-only', '-mstrict-align', '-fno-stack-protector')
& "$llvm\clang.exe" @cf -c "$d\shim.S" -o "$o\shim.o"
& "$llvm\clang.exe" @cf -c "$d\shimc.c" -o "$o\shimc.o"
& "$llvm\ld.lld.exe" --image-base=0 -Ttext=0 -N --build-id=none "$o\shim.o" "$o\shimc.o" -o "$o\shim.elf"
& "$llvm\llvm-objcopy.exe" -O binary "$o\shim.elf" "$o\shim.bin"
function Pad([byte[]]$b) { $n = [Math]::Ceiling($b.Length / 4096) * 4096; $r = New-Object byte[] $n; [Array]::Copy($b, $r, $b.Length); ,$r }
$shim = Pad ([IO.File]::ReadAllBytes("$o\shim.bin"))
$dtb = Pad ([IO.File]::ReadAllBytes("$o\milos-nothing-asteroids.dtb"))
$k = [IO.File]::ReadAllBytes("$o\Image")
[BitConverter]::GetBytes([uint64]$shim.Length).CopyTo($shim, 64)
[BitConverter]::GetBytes([uint64]($shim.Length + $dtb.Length)).CopyTo($shim, 72)
[BitConverter]::GetBytes([uint64]$k.Length).CopyTo($shim, 80)
if (Test-Path "$o\initramfs.cpio.gz") {
	[BitConverter]::GetBytes([uint64](Get-Item "$o\initramfs.cpio.gz").Length).CopyTo($shim, 88)
	$fs = [IO.File]::OpenRead("$o\initramfs.cpio.gz"); $m = New-Object byte[] 8; [void]$fs.Read($m, 0, 8); $fs.Close()
	[Array]::Copy($m, 0, $shim, 96, 8)
}
# the initramfs rides inside our image after the kernel; Linux uses it in place
$kp = Pad $k
$rdp = "$o\initramfs.cpio.gz"
if (Test-Path $rdp) { [BitConverter]::GetBytes([uint64]($shim.Length + $dtb.Length + $kp.Length)).CopyTo($shim, 104) }
$out = [IO.File]::Create("$o\kernel-shim")
$out.Write($shim, 0, $shim.Length); $out.Write($dtb, 0, $dtb.Length); $out.Write($kp, 0, $kp.Length)
if (Test-Path $rdp) { $in = [IO.File]::OpenRead($rdp); $in.CopyTo($out); $in.Close() }   # streamed: may be 500+ MB
$out.Close()
$rd = @()
python "$d\..\mkbootimg\mkbootimg.py" --header_version 4 --kernel "$o\kernel-shim" @rd --os_version 16.0.0 --os_patch_level 2025-09 --cmdline 'console=tty0' -o "$o\pmos-3a-boot.img"
Get-Item "$o\pmos-3a-boot.img"
