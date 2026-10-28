#!/bin/bash
# Apply pmos3a/kernel/*.patch to the kernel tree (once each) and rebuild only msm.ko into the rootfs.
set -e
L=/root/pmos3a/linux
W=/root/rootfs3a
SRC=/mnt/c/Users/qu33rl1nk/nura-3a/pmos3a
K="ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-"
cd $L
for p in $SRC/kernel/*.patch; do
	if git apply --check -R "$p" 2>/dev/null || patch -p1 -R --dry-run -s < "$p" >/dev/null 2>&1; then
		echo "already applied: $(basename $p)"
	else
		patch -p1 -s < "$p" && echo "applied: $(basename $p)"
	fi
done
make $K -j$(nproc) M=drivers/gpu/drm/msm modules
KV=$(ls $W/lib/modules | head -1)
D=$(dirname $(find $W/lib/modules/$KV -name 'msm.ko*' | head -1))
aarch64-linux-gnu-strip --strip-debug -o $D/msm.ko drivers/gpu/drm/msm/msm.ko
rm -f $D/msm.ko.* 2>/dev/null || true
chroot $W depmod $KV
ls -l $D/msm.ko
