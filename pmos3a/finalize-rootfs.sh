#!/bin/bash
# After build-rootfs.sh: enable OpenRC services and autologin into Plasma Mobile (what pmbootstrap does).
set -e
W=/root/rootfs3a
P=/mnt/c/Users/qu33rl1nk/nura-3a/pmos3a/out
[ -d $W/etc ] || { echo "no rootfs"; exit 1; }
chroot $W /bin/sh -c '
for s in devfs dmesg mdev udev udev-trigger; do rc-update add $s sysinit 2>/dev/null; done
for s in hwclock modules sysctl hostname bootmisc syslog; do rc-update add $s boot 2>/dev/null; done
for s in dbus elogind polkit networkmanager tinydm; do rc-update add $s default 2>/dev/null; done
rc-update del mdev sysinit 2>/dev/null
id user >/dev/null 2>&1 || adduser -D -s /bin/sh user
echo user:147147 | chpasswd
for g in video input audio wheel plugdev netdev seat; do addgroup user $g 2>/dev/null; done
command -v tinydm-set-session >/dev/null && tinydm-set-session -f -s /usr/share/wayland-sessions/plasmamobile.desktop
'
mkdir -p $W/etc/conf.d
echo 'autologin="user"' > $W/etc/conf.d/tinydm
# software rendering: no GPU firmware in this rootfs
mkdir -p $W/etc/profile.d
printf 'export LIBGL_ALWAYS_SOFTWARE=1\nexport KWIN_COMPOSE=Q\n' > $W/etc/profile.d/soft-gl.sh
(cd $W && tar -czf $P/rootfs.tar.gz .)
ls -l $P/rootfs.tar.gz
