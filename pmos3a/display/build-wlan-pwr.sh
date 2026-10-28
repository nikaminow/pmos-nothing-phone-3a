#!/bin/bash
# Small 3a helper modules: 3a-wlan-pwr.ko (WCN6755 RF power for Wi-Fi, PMU "wlan" target) and
# 3a-splash-off.ko (stops ABL's splash scanout before msm binds).
set -e
B=/root/wlanpwr
D=/mnt/c/Users/qu33rl1nk/nura-3a/pmos3a/display
rm -rf $B && mkdir -p $B
cp $D/3a-wlan-pwr.c $D/3a-splash-off.c $B/
echo 'obj-m += 3a-wlan-pwr.o 3a-splash-off.o' > $B/Makefile
make -s -C /root/pmos3a/linux ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- M=$B modules
aarch64-linux-gnu-strip --strip-debug $B/3a-wlan-pwr.ko $B/3a-splash-off.ko
cp $B/3a-wlan-pwr.ko $B/3a-splash-off.ko $D/
ls -l $D/3a-wlan-pwr.ko $D/3a-splash-off.ko
