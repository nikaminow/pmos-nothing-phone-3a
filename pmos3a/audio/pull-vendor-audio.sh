#!/bin/sh
# Collect the vendor audio configuration for AUDIO-PLAN stage C (speaker protection on the ADSP):
# ACDB calibration, AudioReach/PAL xml, TFA DSP module libraries. vendor_a is mapped READ-ONLY.
# Run on the phone; the result is /tmp/vendor-audio.tgz (pull it with phone-pull.py).
set -e
S=$(for d in /sys/class/block/sd*; do grep -q '^PARTNAME=super$' $d/uevent && basename $d; done)
blockdev --setro /dev/$S
modprobe dm_mod; modprobe erofs
python3 /usr/local/bin/lp-map.py /dev/$S vendor_a |
	awk -v d=/dev/$S '{print s/512, $2/512, "linear", d, $1/512; s+=$2}' > /tmp/vendor.table
dmsetup create --readonly vendor_a /tmp/vendor.table
mkdir -p /mnt/vendor
mount -t erofs -o ro /dev/mapper/vendor_a /mnt/vendor
cd /mnt/vendor
find etc lib lib64 firmware -iname '*acdb*' -o -iname '*tfa*' -o -iname 'resourcemanager*.xml' \
	-o -iname 'usecaseKvManager*.xml' -o -iname 'kvh2xml*' -o -iname 'mixer_paths*.xml' \
	-o -iname 'card-defs*.xml' -o -iname 'audio_*policy*.xml' -o -iname '*speaker*' 2>/dev/null |
	grep -v '^$' > /tmp/vendor-audio.list
ls -d etc/acdbdata lib/rfsa/adsp 2>/dev/null >> /tmp/vendor-audio.list || true
tar -czf /tmp/vendor-audio.tgz -T /tmp/vendor-audio.list
cd /; umount /mnt/vendor; dmsetup remove vendor_a
wc -l < /tmp/vendor-audio.list; ls -l /tmp/vendor-audio.tgz
