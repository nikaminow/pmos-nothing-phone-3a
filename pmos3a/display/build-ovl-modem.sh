#!/bin/bash
# Modem overlay module: 3a-ovl-modem.ko applies 3a-modem.dtbo (IPA).
set -e
B=/root/ovlm
D=/mnt/c/Users/qu33rl1nk/nura-3a/pmos3a/display
rm -rf $B && mkdir -p $B
sed -e 's/nura-display.dtbo/3a-modem.dtbo/' /mnt/c/Users/qu33rl1nk/nura-3a/upstream-4a/kernel/nura-ovl/nura-ovl.c > $B/3a-ovl-modem.c
echo 'obj-m += 3a-ovl-modem.o' > $B/Makefile
make -s -C /root/pmos3a/linux ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- M=$B modules
aarch64-linux-gnu-strip --strip-debug $B/3a-ovl-modem.ko
dtc -q -@ -I dts -O dtb -o $D/3a-modem.dtbo $D/3a-modem.dts
cp $B/3a-ovl-modem.ko $D/
ls -l $D/3a-ovl-modem.ko $D/3a-modem.dtbo
