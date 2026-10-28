#!/bin/bash
# tinydm autologins UID 10000 into the session set by tinydm-set-session.
set -e
W=/root/rootfs3a
P=/mnt/c/Users/qu33rl1nk/nura-3a/pmos3a/out
chroot $W /bin/sh -c '
deluser --remove-home user 2>/dev/null || true
adduser -D -u 10000 -s /bin/sh user
echo user:147147 | chpasswd
for g in video input audio wheel plugdev netdev seat; do addgroup user $g 2>/dev/null || true; done
tinydm-set-session -f -s /usr/share/wayland-sessions/plasma-mobile.desktop
id user
'
mkdir -p $W/etc/profile.d
printf 'export LIBGL_ALWAYS_SOFTWARE=1\n' > $W/etc/profile.d/soft-gl.sh
(cd $W && tar -czf $P/rootfs.tar.gz .)
ls -l $P/rootfs.tar.gz
