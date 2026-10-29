#!/bin/bash
# AudioReach topology for the 3a: Nothing-Phone-3a.m4 (+ the TFA macros here) -> Nothing-Phone-3a-tplg.bin
# Needs linux-msm/audioreach-topology in /root/audioreach-topology, m4 and alsatplg (alsa-utils).
set -e
T=/root/audioreach-topology
P=/mnt/c/Users/qu33rl1nk/nura-3a/pmos3a/audio
sed -i 's/\r$//' $P/*.m4
cd /tmp && m4 -I $P -I $T $P/Nothing-Phone-3a.m4 > /tmp/3a-tplg.conf
# the routes to BE DAI widgets are created by the kernel: alsatplg's "undefined widget" lines are expected
alsatplg -c /tmp/3a-tplg.conf -o $P/Nothing-Phone-3a-tplg.bin 2>&1 | grep -v 'undefined \(source\|sink\) widget' || true
grep -c tfadsp_rx /tmp/3a-tplg.conf
ls -l $P/Nothing-Phone-3a-tplg.bin
