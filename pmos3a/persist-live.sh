#!/bin/bash
# Carry the fixes made live on the phone into the rootfs (run after each such fix, then repack).
set -e
W=/root/rootfs3a
P=/mnt/c/Users/qu33rl1nk/nura-3a/pmos3a
KV=$(ls $W/lib/modules | head -1)
# environment: no legacy DRM, no Qt scale (both broke Plasma); QT_QUICK_BACKEND=software stays: plasmashell crashes without it (no GPU yet)
sed -i -e /KWIN_DRM_NO_AMS/d -e /QT_SCALE_FACTOR/d $W/etc/environment $W/etc/profile.d/soft-gl.sh
grep -q QT_QUICK_BACKEND $W/etc/environment || echo 'QT_QUICK_BACKEND=software' >> $W/etc/environment
grep -q QT_QUICK_BACKEND $W/etc/profile.d/soft-gl.sh || echo 'export QT_QUICK_BACKEND=software' >> $W/etc/profile.d/soft-gl.sh
# display: panel driver + overlay module + overlay
mkdir -p $W/lib/modules/$KV/extra
cp $P/display/panel-raydium-rm69220.ko $P/display/3a-ovl.ko $P/display/3a-ovl-gpu.ko $W/lib/modules/$KV/extra/
cp $P/display/3a-display.dtbo $P/display/3a-gpu.dtbo $W/lib/firmware/
chroot $W depmod $KV
install -D -m 755 /mnt/c/Users/qu33rl1nk/nura-3a/upstream-4a/tools/pil-squash.py $W/usr/local/bin/pil-squash.py
install -D -m 755 $P/lp-map.py $W/usr/local/bin/lp-map.py
# remote processors stay blacklisted for udev: autoloaded at boot they find no firmware yet and
# never retry (ADSP/CDSP -2); 3a-hw loads them by name after pil-squash
grep -q qcom_q6v5_pas $W/etc/modprobe.d/3a-blacklist.conf || echo 'blacklist qcom_q6v5_pas' >> $W/etc/modprobe.d/3a-blacklist.conf
cat > $W/etc/init.d/3a-hw <<'EOF'
#!/sbin/openrc-run
# Nothing Phone (3a) RAM boot: CPU at full speed, real display driver before the UI starts.
description="3a hardware bring-up"
depend() {
	need localmount
	before tinydm
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
		umount /mnt/vendor
		dmsetup remove vendor_a
	fi
	# 3a.nodisplay on the kernel command line: keep simplefb, load the display by hand
	grep -q 3a.nodisplay /proc/cmdline || {
		modprobe dispcc_milos
		modprobe msm
		modprobe panel-raydium-rm69220
		modprobe 3a-ovl
		sleep 2
		# the first bind fails: MDP still scans ABL's splash when the SMMU attaches (faults,
		# mdp_clk_src stuck, DSI cmd -110, white/black screen); a second bind starts clean
		# GPU joins only the second bind: unbinding a bound Adreno trips msm_gem and the rebind fails
		echo ae00000.display-subsystem > /sys/bus/platform/drivers/msm-mdss/unbind
		[ -f /lib/firmware/qcom/gen80300_sqe.fw ] && modprobe 3a-ovl-gpu
		sleep 1
		echo ae00000.display-subsystem > /sys/bus/platform/drivers/msm-mdss/bind
		sleep 2
	}
	# firmware straight from the phone's own modem_a, READ-ONLY (never write to UFS)
	F=/lib/firmware/qcom/milos/nothing/asteroids
	M=$(for d in /sys/class/block/sd*; do grep -q '^PARTNAME=modem_a$' $d/uevent && basename $d; done)
	if [ -n "$M" ] && [ ! -f $F/adsp.mbn ]; then
		mkdir -p /mnt/modem
		mount -t vfat -o ro,shortname=lower /dev/$M /mnt/modem
		python3 /usr/local/bin/pil-squash.py /mnt/modem/image $F >/dev/null
		cp /mnt/modem/image/*.jsn $F/
		umount /mnt/modem
	fi
	# ADSP/CDSP: battery and charging via pmic-glink (modem, Wi-Fi: later)
	modprobe qcom_pd_mapper
	modprobe qcom_q6v5_pas
	sleep 5
	modprobe qcom_battmgr
	eend 0
}
EOF
chmod +x $W/etc/init.d/3a-hw
chroot $W rc-update add 3a-hw default >/dev/null
# KWin output scale 3.1 (kwinoutputconfig.json from the phone, if pulled)
[ -f $P/kwinoutputconfig.json ] && { mkdir -p $W/home/user/.config; cp $P/kwinoutputconfig.json $W/home/user/.config/; chown -R 10000:10000 $W/home/user/.config; }
(cd $W && tar -czf $P/out/rootfs.tar.gz .)
ls -l $P/out/rootfs.tar.gz
