#!/bin/bash
# Wi-Fi + Bluetooth overlay (3a-wifi.dtbo, loaded by 3a-ovl-wifi.ko). Firmware comes from the
# phone at boot (3a-hw): WPSS + bdwlan from modem_a, BT from bluetooth_a.
set -e
L=/root/pmos3a/linux
D=/mnt/c/Users/qu33rl1nk/nura-3a/pmos3a/display
cpp -nostdinc -I $L/include -I $L/arch/arm64/boot/dts/qcom -undef -D__DTS__ -x assembler-with-cpp \
	$D/3a-wifi.dts -o /tmp/3a-wifi.pp.dts
dtc -q -@ -I dts -O dtb -o $D/3a-wifi.dtbo /tmp/3a-wifi.pp.dts
ls -l $D/3a-wifi.dtbo
