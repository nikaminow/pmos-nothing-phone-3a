#!/bin/bash
set -e
W=/root/pmos3a
SRC=/mnt/c/Users/qu33rl1nk/nura-3a
mkdir -p $W && cd $W
apt-get install -y -qq git build-essential bc bison flex libssl-dev gcc-aarch64-linux-gnu device-tree-compiler cpio kmod >/dev/null
if [ ! -d linux ]; then
	rm -rf linux; git init -q linux && cd linux
	git remote add origin https://github.com/milos-mainline/linux
	git fetch -q --depth 1 origin $(tr -d "\r\n " < $SRC/upstream-4a/kernel/BASE_COMMIT)
	git checkout -q FETCH_HEAD
	tr -d "\r" < $SRC/upstream-4a/kernel/nura-frogger-milos-7.2.patch > /tmp/nura.patch; git apply /tmp/nura.patch || git apply --reject /tmp/nura.patch || true
	cd ..
fi
cd linux

grep -q asteroids arch/arm64/boot/dts/qcom/Makefile || echo 'dtb-$(CONFIG_ARCH_QCOM) += milos-nothing-asteroids.dtb' >> arch/arm64/boot/dts/qcom/Makefile
cp $SRC/upstream-4a/kernel/config-milos.aarch64 .config
./scripts/config -e SPI_QCOM_GENI -e FB_SIMPLE -e DRM_SIMPLEDRM -e FRAMEBUFFER_CONSOLE -e VT -e VT_CONSOLE -e SYSFB_SIMPLEFB
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig >/dev/null
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) Image
mkdir -p $SRC/pmos3a/out
cp arch/arm64/boot/Image $SRC/pmos3a/out/
echo BUILD_OK
