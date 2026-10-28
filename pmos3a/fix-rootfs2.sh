#!/bin/bash
# KWin loop on the 3a (no GPU firmware): software compositing, and the deviceinfo pmOS scripts expect.
set -e
W=/root/rootfs3a
P=/mnt/c/Users/qu33rl1nk/nura-3a/pmos3a/out
cat > $W/etc/deviceinfo <<'EOF'
deviceinfo_format_version="0"
deviceinfo_name="Nothing Phone (3a)"
deviceinfo_manufacturer="Nothing"
deviceinfo_codename="nothing-asteroids"
deviceinfo_arch="aarch64"
deviceinfo_chassis="handset"
deviceinfo_screen_width="1080"
deviceinfo_screen_height="2392"
deviceinfo_dtb="qcom/milos-nothing-asteroids"
EOF
ENV='KWIN_COMPOSE=Q
LIBGL_ALWAYS_SOFTWARE=1
QT_QUICK_BACKEND=software
KWIN_DRM_NO_AMS=1
QT_SCALE_FACTOR=2'
echo "$ENV" > $W/etc/environment
echo "$ENV" | sed 's/^/export /' > $W/etc/profile.d/soft-gl.sh
(cd $W && tar -czf $P/rootfs.tar.gz .)
ls -l $P/rootfs.tar.gz
