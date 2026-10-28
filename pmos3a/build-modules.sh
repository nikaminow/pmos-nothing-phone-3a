#!/bin/bash
# After build-kernel.sh: all modules into the rootfs, DTB with UFS, repacked rootfs.
set -e
L=/root/pmos3a/linux
W=/root/rootfs3a
SRC=/mnt/c/Users/qu33rl1nk/nura-3a/pmos3a
while pgrep -f 'make ARCH=arm64' >/dev/null; do sleep 20; done   # the Image build
cd $L
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) modules
rm -rf $W/lib/modules
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- INSTALL_MOD_PATH=$W INSTALL_MOD_STRIP=1 modules_install
# never mount the phone's storage by itself: udisks/automount off, the user's data is on it
rm -f $W/etc/runlevels/*/udisks2 2>/dev/null || true
echo 'blacklist ufs_qcom_never_autoload_placeholder' > /dev/null
bash $SRC/build-dtb.sh | tail -1
(cd $W && tar -czf $SRC/out/rootfs.tar.gz .)
ls -l $SRC/out/rootfs.tar.gz $SRC/out/Image
echo MODULES_OK
