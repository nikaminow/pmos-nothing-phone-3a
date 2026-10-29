#!/bin/bash
# Speaker amps stage A (AUDIO-PLAN.md): 3a-audio-i2c.dtbo (bare I2C bus) + 3a-ovl-audio-i2c.ko.
set -e
L=/root/pmos3a/linux
B=/root/audio-i2c
D=/mnt/c/Users/qu33rl1nk/nura-3a/pmos3a/display
rm -rf $B && mkdir -p $B
sed -e 's/nura-display.dtbo/3a-audio-i2c.dtbo/' /mnt/c/Users/qu33rl1nk/nura-3a/upstream-4a/kernel/nura-ovl/nura-ovl.c > $B/3a-ovl-audio-i2c.c
echo 'obj-m += 3a-ovl-audio-i2c.o' > $B/Makefile
make -s -C $L ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- M=$B modules
aarch64-linux-gnu-strip --strip-debug $B/3a-ovl-audio-i2c.ko
cp $B/3a-ovl-audio-i2c.ko $D/
cpp -nostdinc -I /root/dts/include -I /root/dts/arch/arm64/boot/dts/qcom -undef -D__DTS__ \
	-x assembler-with-cpp $D/3a-audio-i2c.dts -o /tmp/3a-audio-i2c.pp.dts
dtc -q -@ -I dts -O dtb -o $D/3a-audio-i2c.dtbo /tmp/3a-audio-i2c.pp.dts
ls -l $D/3a-ovl-audio-i2c.ko $D/3a-audio-i2c.dtbo
