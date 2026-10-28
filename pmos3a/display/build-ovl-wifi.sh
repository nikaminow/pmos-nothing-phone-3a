#!/bin/bash
# Second overlay module for Wi-Fi: 3a-ovl.ko stays loaded (unloading it would drop the display overlay).
set -e
B=/root/ovlw
D=/mnt/c/Users/qu33rl1nk/nura-3a/pmos3a/display
rm -rf $B && mkdir -p $B
sed -e 's/nura-display.dtbo/3a-wifi.dtbo/' /mnt/c/Users/qu33rl1nk/nura-3a/upstream-4a/kernel/nura-ovl/nura-ovl.c > $B/3a-ovl-wifi.c
echo 'obj-m += 3a-ovl-wifi.o' > $B/Makefile
make -s -C /root/pmos3a/linux ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- M=$B modules
aarch64-linux-gnu-strip --strip-debug $B/3a-ovl-wifi.ko
cp $B/3a-ovl-wifi.ko $D/
ls -l $D/3a-ovl-wifi.ko
