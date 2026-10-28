#!/bin/bash
set -e
P=/mnt/c/Users/qu33rl1nk/nura-3a/pmos3a
R=/root/initramfs
rm -rf $R && mkdir -p $R/bin
if [ ! -f /root/busybox.static ]; then
	V=$(wget -qO- https://dl-cdn.alpinelinux.org/alpine/v3.20/main/aarch64/ | grep -o 'busybox-static-[0-9.r-]*\.apk' | head -1)
	wget -qO /tmp/bb.apk https://dl-cdn.alpinelinux.org/alpine/v3.20/main/aarch64/$V
	tar -xzf /tmp/bb.apk -C /tmp bin/busybox.static 2>/dev/null
	mv /tmp/bin/busybox.static /root/busybox.static
fi
cp /root/busybox.static $R/bin/busybox
tr -d '\r' < $P/initramfs/init > $R/init
chmod +x $R/init $R/bin/busybox
(cd $R && find . | cpio -o -H newc 2>/dev/null | gzip -9) > $P/out/initramfs.cpio.gz
SZ=$(stat -c %s $P/out/initramfs.cpio.gz)
fdtput -t x $P/out/milos-nothing-asteroids.dtb /chosen linux,initrd-end 9 $(printf '%x' $((0x10000000 + SZ)))
ls -l $P/out/initramfs.cpio.gz
