#!/bin/bash
# The whole Plasma Mobile rootfs as the initramfs (zstd): one fastboot boot, no USB network.
set -e
W=/root/rootfs3a
P=/mnt/c/Users/qu33rl1nk/nura-3a/pmos3a/out
ln -sf /sbin/init $W/init
(cd $W && find . -xdev | cpio -o -H newc 2>/dev/null | zstd -19 -T0 -q) > /root/initramfs.zst
SZ=$(stat -c %s /root/initramfs.zst)
echo "initramfs $((SZ >> 20)) MiB"
[ $SZ -lt $((700 << 20)) ] || { echo "too big for fastboot (768 MiB with the kernel)"; exit 1; }
cp /root/initramfs.zst $P/initramfs.cpio.gz
fdtput -t x $P/milos-nothing-asteroids.dtb /chosen linux,initrd-end 9 $(printf '%x' $((0x10000000 + SZ)))
echo OK
