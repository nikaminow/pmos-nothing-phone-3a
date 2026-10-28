#!/bin/bash
# Wi-Fi overlay + WCN6750 firmware (Alpine linux-firmware-ath11k) as one tarball to push.
set -e
D=/mnt/c/Users/qu33rl1nk/nura-3a/pmos3a/display
dtc -q -@ -I dts -O dtb -o $D/3a-wifi.dtbo $D/3a-wifi.dts
cd /tmp && rm -rf fwath && mkdir fwath && cd fwath
U=https://dl-cdn.alpinelinux.org/alpine/v3.24/main/aarch64
V=$(wget -qO- $U/ | grep -o 'linux-firmware-ath11k-[0-9a-z._-]*\.apk' | head -1)
wget -qO a.apk $U/$V
tar -xzf a.apk 2>/dev/null || true
ls lib/firmware/ath11k
tar -czf $D/ath11k-wcn6750.tgz lib/firmware/ath11k/WCN6750
ls -l $D/3a-wifi.dtbo $D/ath11k-wcn6750.tgz
