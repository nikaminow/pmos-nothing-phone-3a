#!/bin/bash
# postmarketOS edge + Plasma Mobile rootfs for the 3a RAM boot (no firmware: GPU falls back to llvmpipe).
set -e
W=/root/rootfs3a
P=/mnt/c/Users/qu33rl1nk/nura-3a/pmos3a/out
apt-get install -y -qq qemu-user-binfmt >/dev/null
if [ ! -x /root/apk.static ]; then
	V=$(wget -qO- https://dl-cdn.alpinelinux.org/alpine/v3.22/main/x86_64/ | grep -o 'apk-tools-static-[0-9.r-]*\.apk' | head -1)
	wget -qO /tmp/apks.apk https://dl-cdn.alpinelinux.org/alpine/v3.22/main/x86_64/$V
	tar -xzf /tmp/apks.apk -C /tmp sbin/apk.static 2>/dev/null; mv /tmp/sbin/apk.static /root/apk.static
fi
rm -rf $W && mkdir -p $W/etc/apk $W/usr/bin
cat > $W/etc/apk/repositories <<EOF
https://mirror.postmarketos.org/postmarketos/v26.06
https://dl-cdn.alpinelinux.org/alpine/v3.24/main
https://dl-cdn.alpinelinux.org/alpine/v3.24/community
EOF
/root/apk.static --root $W --initdb --arch aarch64 --allow-untrusted --no-cache add \
	alpine-base postmarketos-base postmarketos-ui-plasma-mobile mesa-dri-gallium greetd \
	openrc busybox-openrc
# autologin user and network on the USB link
chroot $W /bin/sh -c 'adduser -D -s /bin/sh user; echo user:147147 | chpasswd; addgroup user video; addgroup user input' || true
echo 3a > $W/etc/hostname
(cd $W && tar -czf $P/rootfs.tar.gz .)
ls -l $P/rootfs.tar.gz
