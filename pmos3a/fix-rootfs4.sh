#!/bin/bash
# The full module set crashes the 3a after pmOS starts: keep away the drivers that need
# firmware or the display pipeline (none of it is set up yet). Remove lines to bring one back.
set -e
W=/root/rootfs3a
P=/mnt/c/Users/qu33rl1nk/nura-3a/pmos3a/out
cat > $W/etc/modprobe.d/3a-blacklist.conf <<'EOF'
# display / GPU: would take the screen from simpledrm
blacklist msm
blacklist panel_novatek_nt37706a
blacklist dispcc_milos
blacklist gpucc_milos
# video, camera
blacklist venus_core
blacklist venus_dec
blacklist venus_enc
blacklist iris
blacklist qcom_camss
blacklist camcc_milos
blacklist videocc_milos
# remote processors and what talks to them (no firmware yet)
blacklist qcom_q6v5_pas
blacklist qcom_pd_mapper
blacklist qcom_battmgr
blacklist ath11k_ahb
blacklist ipa
blacklist qcom_q6v5_mss
# audio
blacklist snd_soc_sc8280xp
blacklist snd_soc_aw88261
blacklist lpasscc_milos
EOF
(cd $W && tar -czf $P/rootfs.tar.gz .)
ls -l $P/rootfs.tar.gz
