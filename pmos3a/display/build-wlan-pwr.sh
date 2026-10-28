#!/bin/bash
# 3a-wlan-pwr.ko: keeps the WCN6755 RF powered for Wi-Fi (PMU "wlan" target), see 3a-wlan-pwr.c.
set -e
B=/root/wlanpwr
D=/mnt/c/Users/qu33rl1nk/nura-3a/pmos3a/display
rm -rf $B && mkdir -p $B
cp $D/3a-wlan-pwr.c $B/
echo 'obj-m += 3a-wlan-pwr.o' > $B/Makefile
make -s -C /root/pmos3a/linux ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- M=$B modules
aarch64-linux-gnu-strip --strip-debug $B/3a-wlan-pwr.ko
cp $B/3a-wlan-pwr.ko $D/
ls -l $D/3a-wlan-pwr.ko
