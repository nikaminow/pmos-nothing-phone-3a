#!/bin/bash
# Edit the built 3a DTB without the kernel tree: bootargs + a ramoops log buffer.
set -e
O=/mnt/c/Users/qu33rl1nk/nura-3a/pmos3a/out
dtc -q -I dtb -O dts -o /tmp/a.dts $O/milos-nothing-asteroids.dtb
# SMMU: let streams without a driver (the display still scanning the splash) bypass;
# panic=0: stay on the panic text instead of rebooting after 10 s.
sed -i 's|bootargs = "console=tty0 ignore_loglevel clk_ignore_unused pd_ignore_unused"|bootargs = "console=tty0 ignore_loglevel clk_ignore_unused pd_ignore_unused arm-smmu.disable_bypass=0 panic=0"|' /tmp/a.dts
grep -q 'disable_bypass=0' /tmp/a.dts || { echo "bootargs not patched"; exit 1; }
# ramoops: last 1 MiB of the only memory bank, kept across a warm reset
if ! grep -q 'ramoops@9fff00000' /tmp/a.dts; then
	sed -i 's|^/dts-v1/;|/dts-v1/;\n/memreserve/ 0x9fff00000 0x100000;|' /tmp/a.dts
	# top-level node: properties of / come first, so append it just before the final "};"
	head -n -1 /tmp/a.dts > /tmp/b.dts
	printf '\tramoops@9fff00000 {\n\t\tcompatible = "ramoops";\n\t\treg = <0x09 0xfff00000 0x00 0x100000>;\n\t\tconsole-size = <0x80000>;\n\t\trecord-size = <0x20000>;\n\t};\n};\n' >> /tmp/b.dts
	mv /tmp/b.dts /tmp/a.dts
fi
dtc -q -I dts -O dtb -o $O/milos-nothing-asteroids.dtb /tmp/a.dts
dtc -q -I dtb -O dts $O/milos-nothing-asteroids.dtb | grep -E 'bootargs|ramoops@'
