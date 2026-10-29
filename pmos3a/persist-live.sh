#!/bin/bash
# Carry the fixes made live on the phone into the rootfs (run after each such fix, then repack).
set -e
W=/root/rootfs3a
P=/mnt/c/Users/qu33rl1nk/nura-3a/pmos3a
KV=$(ls $W/lib/modules | head -1)
# environment: no legacy DRM, no Qt scale (both broke Plasma); rendering on the Adreno 810 by default:
# 3a-hw puts the software-rendering variables back when the GPU did not come up (plasmashell crashes then)
sed -i -e /KWIN_DRM_NO_AMS/d -e /QT_SCALE_FACTOR/d -e /LIBGL_ALWAYS_SOFTWARE/d -e /QT_QUICK_BACKEND/d -e /KWIN_COMPOSE/d \
	$W/etc/environment $W/etc/profile.d/soft-gl.sh
# display: panel driver + overlay module + overlay
mkdir -p $W/lib/modules/$KV/extra
cp $P/display/panel-raydium-rm69220.ko $P/display/3a-ovl.ko $P/display/3a-ovl-gpu.ko $P/display/3a-ovl-wifi.ko $P/display/3a-wlan-pwr.ko $P/display/3a-splash-off.ko \
	$P/display/3a-ovl-haptics.ko $P/display/rt6010-haptics.ko $P/display/3a-ovl-audio-i2c.ko $W/lib/modules/$KV/extra/
cp $P/display/3a-haptics.dtbo $P/display/3a-audio-i2c.dtbo $W/lib/firmware/
install -D -m 644 $P/72-3a-haptics.rules $W/usr/lib/udev/rules.d/72-3a-haptics.rules
cp $P/display/3a-display.dtbo $P/display/3a-gpu.dtbo $P/display/3a-wifi.dtbo $W/lib/firmware/
chroot $W depmod $KV
install -D -m 755 /mnt/c/Users/qu33rl1nk/nura-3a/upstream-4a/tools/pil-squash.py $W/usr/local/bin/pil-squash.py
install -D -m 755 $P/lp-map.py $W/usr/local/bin/lp-map.py
# modem: 3a-hw starts it (3a-modem) after copying EFS to RAM; rmtfs serves only those copies
tr -d '\r' < $P/3a-modem > $W/usr/local/bin/3a-modem && chmod 755 $W/usr/local/bin/3a-modem
cp $P/display/3a-ovl-modem.ko $W/lib/modules/$KV/extra/ && chroot $W depmod $KV
cp $P/display/3a-modem.dtbo $W/lib/firmware/
printf 'command_args="-o /var/lib/rmtfs -r"\n' > $W/etc/conf.d/rmtfs
for s in rmtfs tqftpserv; do chroot $W rc-update del $s default >/dev/null 2>&1 || true; done
# sensors: 3a-sensors copies the DSP libs and sensor config (read-only) and starts hexagonrpcd
chroot $W apk info -e hexagonrpcd-udev >/dev/null || chroot $W apk add -q hexagonrpcd hexagonrpcd-openrc hexagonrpcd-udev
tr -d '\r' < $P/3a-sensors > $W/usr/local/bin/3a-sensors && chmod 755 $W/usr/local/bin/3a-sensors
install -D -m 644 $P/81-3a-sensors.rules $W/usr/lib/udev/rules.d/81-3a-sensors.rules
for s in hexagonrpcd-adsp-rootpd hexagonrpcd-adsp-sensorspd hexagonrpcd-sdsp; do chroot $W rc-update del $s default >/dev/null 2>&1 || true; done
# live kernel log to the PC on the second USB serial port, as early as OpenRC allows
tr -d '\r' < $P/3a-klog > $W/etc/init.d/3a-klog && chmod 755 $W/etc/init.d/3a-klog
chroot $W rc-update add 3a-klog sysinit >/dev/null
# polkit: Plasma may run in a seatless session, so network/modem rights come from the groups;
# polkitd is D-Bus activated, the OpenRC service only loses the bus name and shows "failed"
install -D -m 644 $P/50-3a-user.rules $W/etc/polkit-1/rules.d/50-3a-user.rules
chroot $W rc-update del polkit default >/dev/null 2>&1 || true
# remote processors stay blacklisted for udev: autoloaded at boot they find no firmware yet and
# never retry (ADSP/CDSP -2); 3a-hw loads them by name after pil-squash
grep -q qcom_q6v5_pas $W/etc/modprobe.d/3a-blacklist.conf || echo 'blacklist qcom_q6v5_pas' >> $W/etc/modprobe.d/3a-blacklist.conf
cat > $W/etc/init.d/3a-hw <<'EOF'
#!/sbin/openrc-run
# Nothing Phone (3a) RAM boot: CPU at full speed, real display driver before the UI starts.
description="3a hardware bring-up"
depend() {
	need localmount
	before tinydm greetd display-manager
}
start() {
	ebegin "3a: cpufreq performance, display"
	for p in /sys/devices/system/cpu/cpufreq/policy*; do echo performance > $p/scaling_governor; done
	# GPU firmware from vendor_a inside super, READ-ONLY: dm-linear --readonly + erofs ro
	S=$(for d in /sys/class/block/sd*; do grep -q '^PARTNAME=super$' $d/uevent && basename $d; done)
	if [ -n "$S" ] && [ ! -f /lib/firmware/qcom/gen80300_sqe.fw ]; then
		blockdev --setro /dev/$S
		modprobe dm_mod; modprobe erofs
		python3 /usr/local/bin/lp-map.py /dev/$S vendor_a |
			awk -v d=/dev/$S '{print s/512, $2/512, "linear", d, $1/512; s+=$2}' > /tmp/vendor.table
		dmsetup create --readonly vendor_a /tmp/vendor.table
		mkdir -p /mnt/vendor /lib/firmware/qcom
		mount -t erofs -o ro /dev/mapper/vendor_a /mnt/vendor
		cp /mnt/vendor/firmware/gen80300_* /lib/firmware/qcom/
		# vibration motor waveforms (rt6010-haptics.ko loads them into the chip's RAM)
		H=$(find /mnt/vendor/firmware /mnt/vendor/etc -name haptic_config.bin 2>/dev/null | head -1)
		[ -n "$H" ] && cp $H /lib/firmware/
		umount /mnt/vendor
		dmsetup remove vendor_a
	fi
	# 3a.nodisplay on the kernel command line: keep simplefb, load the display by hand
	grep -q 3a.nodisplay /proc/cmdline || {
		# the failed first bind leaves an msm display snapshot (devcoredump); freed 5 min later it
		# points into the unbound DRM device: NULL deref in devcd_del -> msm_disp_state_free
		echo 1 > /sys/class/devcoredump/disabled
		# with MDP still scanning ABL's splash the first bind fails (SMMU faults, mdp_clk_src
		# stuck, DSI cmd -110): stop the splash first, then one bind with the GPU included
		modprobe 3a-splash-off
		S=$(cat /sys/module/3a_splash_off/parameters/stopped 2>/dev/null)
		[ "$S" = Y ] && [ -f /lib/firmware/qcom/gen80300_sqe.fw ] && modprobe 3a-ovl-gpu
		N=$(dmesg | grep -c 'Failed to initialize panel')
		modprobe dispcc_milos
		modprobe msm
		modprobe panel-raydium-rm69220
		modprobe 3a-ovl
		sleep 3
		if [ "$(dmesg | grep -c 'Failed to initialize panel')" != "$N" ]; then
			# fallback: a second bind starts clean. The GPU joins only then: unbinding a bound
			# Adreno trips msm_gem (and the rebind leaves use-after-free work in msm)
			echo ae00000.display-subsystem > /sys/bus/platform/drivers/msm-mdss/unbind
			[ "$S" = Y ] || { [ -f /lib/firmware/qcom/gen80300_sqe.fw ] && modprobe 3a-ovl-gpu; }
			sleep 1
			echo ae00000.display-subsystem > /sys/bus/platform/drivers/msm-mdss/bind
			sleep 2
		fi
	}
	# no GPU bound (no firmware, nodisplay): Plasma must render in software
	sed -i -e /LIBGL_ALWAYS_SOFTWARE/d -e /QT_QUICK_BACKEND/d -e /KWIN_COMPOSE/d /etc/environment /etc/profile.d/soft-gl.sh
	[ -e /sys/bus/platform/drivers/adreno/3d00000.gpu ] || {
		printf 'KWIN_COMPOSE=Q\nLIBGL_ALWAYS_SOFTWARE=1\nQT_QUICK_BACKEND=software\n' >> /etc/environment
		sed 's/^/export /' /etc/environment | grep -E 'KWIN_COMPOSE|LIBGL|QT_QUICK' >> /etc/profile.d/soft-gl.sh
	}
	# firmware straight from the phone's own modem_a, READ-ONLY (never write to UFS)
	F=/lib/firmware/qcom/milos/nothing/asteroids
	M=$(for d in /sys/class/block/sd*; do grep -q '^PARTNAME=modem_a$' $d/uevent && basename $d; done)
	if [ -n "$M" ] && [ ! -f $F/adsp.mbn ]; then
		mkdir -p /mnt/modem
		mount -t vfat -o ro,shortname=lower /dev/$M /mnt/modem
		python3 /usr/local/bin/pil-squash.py /mnt/modem/image $F >/dev/null
		cp /mnt/modem/image/*.jsn $F/
		# Wi-Fi calibration: board_id is 0xff (unprogrammed), Android's default bdwlan.elf fits
		mkdir -p /lib/firmware/ath11k/WCN6750/hw1.0
		cp /mnt/modem/image/qca6750/bdwlan.elf /lib/firmware/ath11k/WCN6750/hw1.0/board.bin
		# modem configuration (MCFG), fetched by the modem over tqftp
		cp -r /mnt/modem/image/modem_pr $F/
		umount /mnt/modem
	fi
	# Bluetooth firmware (msbtfw12.mbn, msnv12.bin) from bluetooth_a, READ-ONLY
	B=$(for d in /sys/class/block/sd*; do grep -q '^PARTNAME=bluetooth_a$' $d/uevent && basename $d; done)
	if [ -n "$B" ] && [ ! -f /lib/firmware/qca/msnv12.bin ]; then
		mkdir -p /mnt/bt /lib/firmware/qca
		mount -t vfat -o ro,shortname=lower /dev/$B /mnt/bt
		cp /mnt/bt/image/* /lib/firmware/qca/
		umount /mnt/bt
	fi
	# ADSP/CDSP: battery and charging via pmic-glink
	modprobe qcom_pd_mapper
	modprobe qcom_q6v5_pas
	sleep 5
	modprobe qcom_battmgr
	# Wi-Fi + Bluetooth: the WCN6755 RF is powered by the PMU only while Bluetooth holds it,
	# so hci_uart comes before ath11k (else the WPSS firmware asserts on the first scan)
	modprobe 3a-ovl-wifi
	modprobe pwrseq-qcom-wcn
	# the PMU's "wlan" consumer: RF stays powered even with Bluetooth off
	modprobe 3a-wlan-pwr
	modprobe hci_uart
	sleep 3
	# no BD address in the WCN NVM: hci0 stays "unconfigured", bluetoothd never powers it and the
	# PMU drops the RF rails (S1J), so Wi-Fi only receives. A stable address from the SoC serial:
	A=$(printf '%08x' $(cat /sys/devices/soc0/serial_number) | sed 's/\(..\)\(..\)\(..\)\(..\)/\1:\2:\3:\4/')
	btmgmt --index 0 public-addr 22:3a:$A >/dev/null 2>&1
	modprobe ath11k_ahb
	# vibration motor: I2C bus + RT6010 (the driver binds through its compatible)
	modprobe 3a-ovl-haptics
	# modem + SIM + mobile data, in the background (about a minute)
	start-stop-daemon -b -S -x /usr/local/bin/3a-modem
	# sensors (ADSP SSC via hexagonrpcd + libssc), in the background
	start-stop-daemon -b -S -x /usr/local/bin/3a-sensors
	eend 0
}
EOF
chmod +x $W/etc/init.d/3a-hw
chroot $W rc-update add 3a-hw default >/dev/null
# apps: store (apk backend; installs live in RAM until added here), browser, terminal
chroot $W apk info -e mobile-config-firefox >/dev/null || chroot $W apk add -q gnome-software gnome-software-plugin-apk firefox mobile-config-firefox gnome-console
chroot $W apk info -e fastfetch >/dev/null || chroot $W apk add -q fastfetch
# speaker amps stage A (AUDIO-PLAN.md): i2cget for read-only probing; the bus overlay is loaded by hand only
chroot $W apk info -e i2c-tools >/dev/null || chroot $W apk add -q i2c-tools
# locally built binaries (build-phosh.sh, build-hexagonrpcd.sh), originals kept as .orig:
# Phosh with a 42 px top bar (covers the camera hole), hexagonrpcd that drops DSP writes (sensors)
for b in phosh-bar42:/usr/libexec/phosh hexagonrpcd-dropwrites:/usr/bin/hexagonrpcd; do
	s=$P/out/${b%%:*}; d=$W${b#*:}
	[ -f $s ] || continue
	[ -f $d.orig ] || cp -a $d $d.orig
	install -m 755 $s $d
done
# Phosh (postmarketos-ui-phosh): greetd + phrog instead of tinydm; panel DSI-2 at scale 3 (360x797)
chroot $W rc-update del tinydm default >/dev/null 2>&1 || true
chroot $W rc-update add greetd default >/dev/null
mkdir -p $W/etc/phosh
[ -f $W/etc/phosh/phoc.ini ] || cp $W/usr/share/phosh/phoc.ini $W/etc/phosh/phoc.ini
for f in $W/etc/phosh/phoc.ini $W/usr/share/phrog/phoc.ini; do
	grep -q 'output:DSI-2' $f || printf '\n[output:DSI-2]\nscale = 3\n' >> $f
done
# display cutout + rounded corners for Phosh (gmobile looks up <dt compatible>.json); the camera hole
# from Android's product overlay FrameworksResCommon_Sys_Asteroids (circle at 540,68.6 r 21.5)
if [ -f $P/nothing,asteroids.json ]; then
	install -D -m 644 $P/nothing,asteroids.json $W/usr/share/gmobile/display-panels/nothing,asteroids.json
	rm -rf $W/etc/gmobile $W/etc/xdg/gmobile
	# gmobile reads panels only from its built-in GResource: overlay that path with the directory
	O='G_RESOURCE_OVERLAYS=/mobi/phosh/gmobile/devices/display-panels=/usr/share/gmobile/display-panels'
	sed -i /G_RESOURCE_OVERLAYS/d $W/etc/environment $W/etc/profile.d/soft-gl.sh
	echo "$O" >> $W/etc/environment
	echo "export $O" >> $W/etc/profile.d/soft-gl.sh
fi
# KWin output scale 3.1 (kwinoutputconfig.json from the phone, if pulled)
[ -f $P/kwinoutputconfig.json ] && { mkdir -p $W/home/user/.config; cp $P/kwinoutputconfig.json $W/home/user/.config/; chown -R 10000:10000 $W/home/user/.config; }
# squashfs (zlib: fast to decompress on the phone), mounted read-only + tmpfs overlay by the initramfs
rm -f $P/out/rootfs.sqfs.tmp
mksquashfs $W $P/out/rootfs.sqfs.tmp -comp gzip -b 256K -noappend -quiet -no-progress -wildcards \
	-e 'proc/*' 'sys/*' 'dev/*' 'run/*' 'tmp/*'
mv -f $P/out/rootfs.sqfs.tmp $P/out/rootfs.sqfs
ls -l $P/out/rootfs.sqfs
