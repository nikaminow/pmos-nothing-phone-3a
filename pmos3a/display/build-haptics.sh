#!/bin/bash
# Vibration motor: rt6010-haptics.ko (driver), 3a-haptics.dtbo (I2C bus + chip) and
# 3a-ovl-haptics.ko (applies the overlay).
set -e
L=/root/pmos3a/linux
B=/root/haptics
D=/mnt/c/Users/qu33rl1nk/nura-3a/pmos3a/display
K="ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-"
rm -rf $B && mkdir -p $B
cp $D/rt6010-haptics.c $B/
sed -e 's/nura-display.dtbo/3a-haptics.dtbo/' /mnt/c/Users/qu33rl1nk/nura-3a/upstream-4a/kernel/nura-ovl/nura-ovl.c > $B/3a-ovl-haptics.c
echo 'obj-m += rt6010-haptics.o 3a-ovl-haptics.o' > $B/Makefile
make -s -C $L $K M=$B modules
aarch64-linux-gnu-strip --strip-debug $B/rt6010-haptics.ko $B/3a-ovl-haptics.ko
cp $B/rt6010-haptics.ko $B/3a-ovl-haptics.ko $D/
cpp -nostdinc -I /root/dts/include -I /root/dts/arch/arm64/boot/dts/qcom -undef -D__DTS__ \
	-x assembler-with-cpp $D/3a-haptics.dts -o /tmp/3a-haptics.pp.dts
dtc -q -@ -I dts -O dtb -o $D/3a-haptics.dtbo /tmp/3a-haptics.pp.dts
ls -l $D/rt6010-haptics.ko $D/3a-ovl-haptics.ko $D/3a-haptics.dtbo
