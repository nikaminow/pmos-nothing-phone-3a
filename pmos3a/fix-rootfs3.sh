#!/bin/bash
# Root shell on the USB serial port (COM on the PC) for debugging, then repack.
set -e
W=/root/rootfs3a
P=/mnt/c/Users/qu33rl1nk/nura-3a/pmos3a/out
grep -q ttyGS0 $W/etc/inittab || echo 'ttyGS0::respawn:/sbin/getty -n -l /bin/sh -L ttyGS0 115200 vt100' >> $W/etc/inittab
grep ttyGS0 $W/etc/inittab
(cd $W && tar -czf $P/rootfs.tar.gz .)
ls -l $P/rootfs.tar.gz
