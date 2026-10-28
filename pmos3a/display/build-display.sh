#!/bin/bash
# Panel driver module (from mainline), overlay module (Nura's nura-ovl.c) and the 3a display overlay.
set -e
L=/root/pmos3a/linux
SRC=/mnt/c/Users/qu33rl1nk/nura-3a
D=$SRC/pmos3a/display
B=/root/display-build
K="ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-"
rm -rf $B && mkdir -p $B/panel $B/ovl
cp $SRC/ref-linux/master_drivers_gpu_drm_panel_panel-raydium-rm69220.c $B/panel/panel-raydium-rm69220.c
# newer than our kernel; our msm DSI host does not know the flag anyway
sed -i '0,/#include <drm\/drm_panel.h>/s//#include <drm\/drm_panel.h>\n#ifndef MIPI_DSI_MODE_DSC_ALL_SLICES_IN_PKT\n#define MIPI_DSI_MODE_DSC_ALL_SLICES_IN_PKT 0\n#endif/' $B/panel/panel-raydium-rm69220.c
echo 'obj-m += panel-raydium-rm69220.o' > $B/panel/Makefile
cp $SRC/upstream-4a/kernel/nura-ovl/nura-ovl.c $B/ovl/3a-ovl.c
sed -i 's/nura-display.dtbo/3a-display.dtbo/' $B/ovl/3a-ovl.c
echo 'obj-m += 3a-ovl.o' > $B/ovl/Makefile
make -C $L $K M=$B/panel modules
make -C $L $K M=$B/ovl modules
cpp -nostdinc -I $L/include -I $L/arch/arm64/boot/dts/qcom -undef -D__DTS__ -x assembler-with-cpp \
	$D/3a-display.dts -o /tmp/3a-display.pp.dts
dtc -q -@ -I dts -O dtb -o $D/3a-display.dtbo /tmp/3a-display.pp.dts
cp $B/panel/panel-raydium-rm69220.ko $B/ovl/3a-ovl.ko $D/
ls -l $D/*.ko $D/*.dtbo
