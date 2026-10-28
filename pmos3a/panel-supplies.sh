#!/bin/bash
# Resolve the 3a panel's supplies in ABL's DTB (abl.dts).
cd /mnt/c/Users/qu33rl1nk/nura-3a/pmos3a
echo "== panel supply entries (0x5a6)"
grep -n -A40 'phandle = <0x5a6>' abl.dts | grep -e supply-name -e voltage | head -16
for p in 0x28 0x29; do
	echo "== regulator $p"
	grep -n -B14 "phandle = <$p>;" abl.dts | grep -e regulator-name -e 'gpio = ' -e ' {' | tail -3
done
