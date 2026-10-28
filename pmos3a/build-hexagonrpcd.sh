#!/bin/bash
# hexagonrpcd with dropped DSP writes (hexagonrpcd-dropwrites.py), same version as the rootfs package,
# built in an aarch64 chroot copy of the rootfs.
set -e
W=/root/rootfs3a
B=/root/hexrpc-build
P=/mnt/c/Users/qu33rl1nk/nura-3a/pmos3a
V=$(chroot $W apk list -I hexagonrpcd 2>/dev/null | sed -n 's/^hexagonrpcd-\([0-9.]*\)-r.*/\1/p')
rm -rf $B && mkdir -p $B
cp -a $W/. $B/
cp /etc/resolv.conf $B/etc/resolv.conf
chroot $B apk add -q build-base meson ninja-build python3 linux-headers
wget -qO $B/root/hexagonrpc.tar.gz https://github.com/linux-msm/hexagonrpc/archive/refs/tags/v$V.tar.gz
tar -xzf $B/root/hexagonrpc.tar.gz -C $B/root
python3 $P/hexagonrpcd-dropwrites.py $B/root/hexagonrpc-$V
chroot $B sh -c "cd /root/hexagonrpc-$V && meson setup output --prefix=/usr --buildtype=release >/dev/null && ninja -C output"
F=$(find $B/root/hexagonrpc-$V/output -name hexagonrpcd -type f | head -1)
install -m 755 $F $P/out/hexagonrpcd-dropwrites
ls -l $P/out/hexagonrpcd-dropwrites
echo HEXRPC_OK
