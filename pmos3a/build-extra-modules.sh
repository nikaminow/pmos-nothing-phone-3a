#!/bin/bash
# Kernel options turned on after the main kernel build, built as modules into the rootfs without
# rebuilding the Image: leds-aw200xx (Glyph LEDs, aw20036 on i2c7, described by the upstream DTS).
set -e
L=/root/pmos3a/linux
W=/root/rootfs3a
K="ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-"
cd $L
scripts/config --module LEDS_AW200XX
make $K olddefconfig >/dev/null
make $K -j$(nproc) modules_prepare >/dev/null
make $K -j$(nproc) M=drivers/leds modules >/dev/null
KV=$(ls $W/lib/modules | head -1)
D=$W/lib/modules/$KV/kernel/drivers/leds
mkdir -p $D
aarch64-linux-gnu-strip --strip-debug -o $D/leds-aw200xx.ko drivers/leds/leds-aw200xx.ko
chroot $W depmod $KV
modinfo -F vermagic $D/leds-aw200xx.ko
ls -l $D/leds-aw200xx.ko
