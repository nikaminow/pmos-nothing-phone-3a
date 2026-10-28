#!/bin/bash
# Third overlay module for the GPU: 3a-ovl.ko stays loaded (unloading it would drop the display overlay).
set -e
B=/root/ovlg
D=/mnt/c/Users/qu33rl1nk/nura-3a/pmos3a/display
rm -rf $B && mkdir -p $B
sed -e 's/nura-display.dtbo/3a-gpu.dtbo/' /mnt/c/Users/qu33rl1nk/nura-3a/upstream-4a/kernel/nura-ovl/nura-ovl.c > $B/3a-ovl-gpu.c
echo 'obj-m += 3a-ovl-gpu.o' > $B/Makefile
make -s -C /root/pmos3a/linux ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- M=$B modules
aarch64-linux-gnu-strip --strip-debug $B/3a-ovl-gpu.ko
dtc -q -@ -I dts -O dtb -o $D/3a-gpu.dtbo $D/3a-gpu.dts
cp $B/3a-ovl-gpu.ko $D/
ls -l $D/3a-ovl-gpu.ko $D/3a-gpu.dtbo
