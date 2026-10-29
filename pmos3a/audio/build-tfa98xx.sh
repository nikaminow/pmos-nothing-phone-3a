#!/bin/bash
# Speaker amps: NXP tfa98xx driver from Nothing's sm7635 kernel (vendor/qcom/opensource/
# audio-kernel/asoc/codecs/tfa98xx, GPL), ported to Linux 7.2 -> snd-soc-tfa98xx.ko.
# Built as TFA_NON_DSP_SOLUTION, as on Android: the TFA9873 has no DSP, protection runs on the ADSP.
set -e
L=/root/pmos3a/linux
B=/root/tfa-build
D=/mnt/c/Users/qu33rl1nk/nura-3a/pmos3a/audio
K="ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-"
rm -rf $B && mkdir -p $B
cp -r $D/tfa98xx/src $D/tfa98xx/inc $B/
cat > $B/Makefile <<'EOF'
ccflags-y += -I$(src)/inc -DTFA_NON_DSP_SOLUTION -Wno-error
obj-m += snd-soc-tfa98xx.o
snd-soc-tfa98xx-y := src/tfa98xx.o src/tfa_container.o src/tfa_dsp.o src/tfa_init.o
EOF
make -s -C $L $K M=$B modules 2>&1 | grep -E 'error|Error' | head -${ERRS:-40}
aarch64-linux-gnu-strip --strip-debug $B/snd-soc-tfa98xx.ko
cp $B/snd-soc-tfa98xx.ko $D/
ls -l $D/snd-soc-tfa98xx.ko
