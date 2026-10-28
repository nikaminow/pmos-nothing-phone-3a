# postmarketOS on the Nothing Phone (3a)

Mainline Linux and Plasma Mobile on the Nothing Phone (3a) "Asteroids" (SM7635 / milos).
It boots **from RAM only**: `fastboot boot`, nothing is flashed, Android and its data stay intact.

Based on [Nura](https://github.com/UnderWeek/nura-nothing-phone-4a) for the Phone (4a) "Frogger", which has the same SoC.
The kernel is [milos-mainline](https://github.com/milos-mainline/linux) 7.2 with the Nura patch.

## Status

| Works | Notes |
|---|---|
| Plasma Mobile, touch | focaltech ft3683g on spi0 |
| Display, 120 Hz | msm DPU + DSI + panel-raydium-rm69220 (BOE BF068MWM-TD0), runtime overlay |
| CPU at full clock | governor `performance` |
| Battery level | ADSP + `qcom_battmgr` |
| GPU (Adreno 810) | firmware loads; Plasma still renders in software |

In progress: Wi-Fi (WPSS boots), then Bluetooth, modem, audio, camera.
Details, pitfalls and the day-by-day log: [PMOS-3A-PLAN.md](PMOS-3A-PLAN.md).

## How it boots

```
fastboot boot pmos3a/out/pmos-3a-boot.img
  -> shim (shim.S + shimc.c): Linux at 0x9_0020_0000, our DTB, embedded initramfs
  -> busybox initramfs: USB CDC ACM gadget (COM port on the PC)
  -> python pmos3a/send-rootfs.py: rootfs.tar.gz over the COM port -> tmpfs -> switch_root
  -> OpenRC -> 3a-hw service (firmware, display, GPU, DSPs) -> tinydm -> Plasma Mobile
```

Firmware is never shipped here. The `3a-hw` service reads it at boot from the phone's own
partitions, read-only: `modem_a` (ADSP/CDSP) and `vendor_a` inside `super` (GPU, via `lp-map.py`).

## Building

Host: Windows with WSL Ubuntu (scripts use `/mnt/c/Users/...` paths, adjust them to yours).

- DTB: `pmos3a/build-dtb.sh`, kernel: `pmos3a/build-kernel.sh`, modules: `pmos3a/build-modules.sh`
- initramfs: `pmos3a/build-initramfs.sh`, rootfs: `pmos3a/build-rootfs.sh` + `pmos3a/persist-live.sh`
- display/GPU overlays: `pmos3a/display/build-display.sh`, `pmos3a/display/build-ovl-gpu.sh`
- boot image: `pmos3a/make-boot.ps1`

Debug tools over the USB serial port: `phone-run.py`, `phone-shell.py`, `phone-push.py`, `phone-pull.py`.
After a crash, the next boot exposes the previous kernel log in `/sys/fs/pstore/console-ramoops-0`.

## Safety

Only `fastboot boot`. Never `fastboot flash`, never write to UFS: the scripts mount phone partitions
read-only and mark `super` read-only before mapping it.
