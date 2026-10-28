#!/bin/bash
# Build the RAM-boot 3a DTB from the milos-mainline DT sources only (no kernel tree).
set -e
SRC=/mnt/c/Users/qu33rl1nk/nura-3a
W=/root/dts
C=$(tr -d '\r\n ' < $SRC/upstream-4a/kernel/BASE_COMMIT)
if [ ! -d $W/.git ]; then
	git init -q $W && cd $W
	git remote add origin https://github.com/milos-mainline/linux
	git sparse-checkout set --no-cone /arch/arm64/boot/dts/qcom/ /include/dt-bindings/ /scripts/dtc/include-prefixes/
	git fetch -q --depth 1 --filter=blob:none origin $C
	git checkout -q FETCH_HEAD
fi
cd $W
cp $SRC/pmos3a/milos-nothing-asteroids-ram.dts arch/arm64/boot/dts/qcom/
head -c 1048576 /dev/zero > arch/arm64/boot/dts/qcom/abl-placeholder.bin
cpp -nostdinc -I include -I arch/arm64/boot/dts/qcom -I arch/arm64/boot/dts -undef -D__DTS__ \
	-x assembler-with-cpp arch/arm64/boot/dts/qcom/milos-nothing-asteroids-ram.dts -o /tmp/ram.pp.dts
dtc -q -@ -i arch/arm64/boot/dts/qcom -I dts -O dtb -o $SRC/pmos3a/out/milos-nothing-asteroids.dtb /tmp/ram.pp.dts
dtc -q -I dtb -O dts $SRC/pmos3a/out/milos-nothing-asteroids.dtb | grep -E 'model|bootargs|dr_mode|memory@9'
