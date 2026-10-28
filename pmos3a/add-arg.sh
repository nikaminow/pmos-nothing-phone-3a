#!/bin/bash
# append boot-args to the 3a DTB: add-arg.sh "arg1 arg2"
set -e
O=/mnt/c/Users/qu33rl1nk/nura-3a/pmos3a/out
dtc -q -I dtb -O dts -o /tmp/a.dts $O/milos-nothing-asteroids.dtb
for a in $1; do
	grep -q "bootargs = \".*\b$a\b" /tmp/a.dts || sed -i "s|\(bootargs = \"[^\"]*\)\"|\1 $a\"|" /tmp/a.dts
done
dtc -q -I dts -O dtb -o $O/milos-nothing-asteroids.dtb /tmp/a.dts
dtc -q -I dtb -O dts $O/milos-nothing-asteroids.dtb | grep bootargs
