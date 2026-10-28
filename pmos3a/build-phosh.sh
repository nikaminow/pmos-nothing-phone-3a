#!/bin/bash
# Phosh with a taller top bar: PHOSH_TOP_BAR_HEIGHT 32 -> 42, so at scale 3 the bar (126 px) covers the
# 3a's camera hole (Android's safe area ends at y=126); Phosh only moves the clock for cutouts.
# Built in an aarch64 chroot (qemu) next to the rootfs, same version and options as Alpine.
set -e
W=/root/rootfs3a
B=/root/phosh-build
V=$(chroot $W apk info -v phosh 2>/dev/null | sed -n 's/^phosh-\([0-9.]*\)-r.*/\1/p')
H=${PHOSH_BAR:-42}
rm -rf $B && mkdir -p $B
cp -a $W/. $B/
cp /etc/resolv.conf $B/etc/resolv.conf
chroot $B apk add -q build-base meson ninja-build xz appstream-dev callaudiod-dev elogind-dev evince-dev \
	evolution-data-server-dev feedbackd-dev gcr-dev gettext-dev glib-dev gmobile-dev gnome-bluetooth-dev \
	gnome-desktop-dev gtk+3.0-dev libadwaita-dev libgudev-dev libhandy1-dev libsecret-dev linux-pam-dev \
	modemmanager-dev networkmanager-dev polkit-elogind-dev pulseaudio-dev qrcodegen-dev upower-dev \
	wayland-dev wayland-protocols
wget -qO $B/root/phosh.tar.xz https://sources.phosh.mobi/releases/phosh/phosh-$V.tar.xz
cat > $B/root/build.sh <<EOF
set -e
cd /root && tar -xf phosh.tar.xz && cd phosh-$V
sed -i 's/\.rc/_rc/' meson.build
sed -i 's/#define PHOSH_TOP_BAR_HEIGHT 32/#define PHOSH_TOP_BAR_HEIGHT $H/' src/top-panel.h
sed -i 's|<property name="height-request">32</property>|<property name="height-request">$H</property>|' src/ui/top-panel.ui
grep -n 'PHOSH_TOP_BAR_HEIGHT $H' src/top-panel.h
meson setup output --prefix=/usr --libexecdir=/usr/libexec -Dphoc_tests=disabled -Dman=false -Dtests=false >/dev/null
ninja -C output src/phosh
EOF
chroot $B sh /root/build.sh
install -m 755 $B/root/phosh-$V/output/src/phosh /mnt/c/Users/qu33rl1nk/nura-3a/pmos3a/out/phosh-bar$H
ls -l /mnt/c/Users/qu33rl1nk/nura-3a/pmos3a/out/phosh-bar$H
echo PHOSH_OK
