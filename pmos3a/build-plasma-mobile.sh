#!/bin/bash
# Rebuild Plasma Mobile's mobileshell QML module (libmobileshellplugin.so, QML compiled in) with
# the 3a fixes: volume and notification popups open below the status bar instead of a fixed
# gridUnit from the top edge, which put them on the camera hole. Builds in a copy of the rootfs
# (same library versions) under qemu; result: out/libmobileshellplugin.so
set -e
V=6.6.6
B=/root/pmb
R=$B/root
P=/mnt/c/Users/qu33rl1nk/nura-3a/pmos3a
mkdir -p $B && cd $B
[ -f plasma-mobile-$V.tar.xz ] || wget -q https://download.kde.org/stable/plasma/$V/plasma-mobile-$V.tar.xz
if [ ! -x $R/usr/bin/cmake ]; then
	rm -rf $R && cp -a /root/rootfs3a $R
	cp /etc/resolv.conf $R/etc/resolv.conf
	/root/apk.static --root $R --arch aarch64 --allow-untrusted --timeout 60 add \
		build-base cmake samurai extra-cmake-modules qt6-qtbase-dev qt6-qtdeclarative-dev \
		qt6-qtsensors-dev qt6-qtwayland-dev qt6-qttools-dev ki18n-dev kglobalaccel-dev kio-dev \
		kconfig-dev kdbusaddons-dev kitemmodels-dev kservice-dev knotifications-dev \
		modemmanager-qt-dev networkmanager-qt-dev kcmutils-dev kpackage-dev kjobwidgets-dev \
		kwindowsystem-dev libplasma-dev plasma-activities-dev libkscreen-dev kwayland-dev \
		kpipewire-dev qcoro-dev kirigami-addons-dev libepoxy-dev libxcb-dev kwin-dev \
		layer-shell-qt-dev wayland-dev plasma-wayland-protocols plasma-workspace-dev eudev-dev \
		kauth-dev
fi
rm -rf $R/build && mkdir -p $R/build && tar xf plasma-mobile-$V.tar.xz -C $R/build
S=$R/build/plasma-mobile-$V/components/mobileshell/qml/popups
sed -i 's/Kirigami.Units.gridUnit + Kirigami.Units.smallSpacing \* 3/MobileShell.Constants.topPanelHeight + Kirigami.Units.smallSpacing * 2/' \
	$S/volumeosd/VolumeChangedPopup.qml $S/volumeosd/VolumeOSD.qml $S/notifications/NotificationPopupManager.qml
grep -c Constants.topPanelHeight $S/volumeosd/VolumeChangedPopup.qml $S/volumeosd/VolumeOSD.qml $S/notifications/NotificationPopupManager.qml
chroot $R /bin/sh -c "cd /build/plasma-mobile-$V && cmake -B b -G Ninja -DCMAKE_BUILD_TYPE=None \
	-DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib -DBUILD_TESTING=OFF >/build/cmake.log 2>&1 \
	&& cmake --build b --target mobileshellplugin -j16 >/build/make.log 2>&1"
F=$(find $R/build/plasma-mobile-$V/b -name libmobileshellplugin.so | head -1)
strip $F 2>/dev/null || aarch64-linux-gnu-strip $F
cp $F $P/out/libmobileshellplugin.so
ls -l $P/out/libmobileshellplugin.so
