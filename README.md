# postmarketOS on the Nothing Phone (3a)

Mainline Linux and Plasma Mobile on the Nothing Phone (3a) "Asteroids" (SM7635 / milos).
It boots **from RAM only**: `fastboot boot`, nothing is flashed, Android and its data stay intact.
Reboot the phone and you are back in Android.

Based on [Nura](https://github.com/UnderWeek/nura-nothing-phone-4a) for the Phone (4a) "Frogger", which has the same SoC.
The kernel is [milos-mainline](https://github.com/milos-mainline/linux) 7.2 with the Nura patch.

## Status

| Works | Notes |
|---|---|
| Plasma Mobile (or Phosh), touch | focaltech ft3683g on spi0 |
| Display, 120 Hz | msm DPU + DSI + panel-raydium-rm69220 (BOE BF068MWM-TD0), runtime overlay |
| GPU (Adreno 810) | hardware OpenGL, firmware read from `vendor_a` |
| Wi-Fi, Bluetooth | WCN6755 (ath11k + hci_uart) |
| Modem: calls/SMS/data | ModemManager over QRTR; EFS copied to RAM, served read-only |
| Battery level | ADSP + `qcom_battmgr` |
| Sensors: accelerometer (auto-rotate), light, proximity, compass | SSC on the ADSP via hexagonrpcd + iio-sensor-proxy |
| Vibration | RT6010, own driver |
| Glyph lights, flashlight | aw200xx LED driver |
| Clock | set from the PC at boot (the RTC offset lives in Android's data) |

Not working yet: speakers (protection runs on the ADSP, see [AUDIO-PLAN.md](pmos3a/AUDIO-PLAN.md)),
microphones and headset (WCD9378 has no mainline driver), cameras ([CAMERA-PLAN.md](pmos3a/CAMERA-PLAN.md)),
SIM slot 2 on some cards, USB host / video out. Only tested on the Phone (3a), not the (3a) Pro.

Details, pitfalls and the day-by-day log: [PMOS-3A-PLAN.md](PMOS-3A-PLAN.md).

## Try it (no flashing)

You need: an **unlocked bootloader**, `fastboot` (Android platform-tools), Python 3.8+, a USB cable.
Files from the [latest release](../../releases/latest): `pmos-3a-boot.img`, `rootfs.sqfs`, `send-rootfs.py`
(keep them in one folder).

1. Reboot the phone into the bootloader: `adb reboot bootloader`, or power off and hold
   Power + Volume down.
2. Boot the image (this does **not** flash anything):
   ```
   fastboot boot pmos-3a-boot.img
   ```
   The screen stays on the splash; the phone now shows up as a USB serial port (18d1:d003).
3. Send the system (about 900 MB, 2-3 minutes):
   - Windows: `python send-rootfs.py` (the COM port is found automatically, no driver needed).
   - Linux: `sudo systemctl stop ModemManager` (it probes new serial ports and would corrupt the
     transfer), then `sudo python3 send-rootfs.py` (or `--port /dev/ttyACM0`).
4. Plasma Mobile starts in about a minute. User `user`, password `147147`.

Back to Android: hold Power until it reboots. The phone partitions are only ever mounted read-only
and all changes live in RAM, so nothing persists between boots.

## How it boots

```
fastboot boot pmos-3a-boot.img
  -> shim (shim.S + shimc.c): Linux at 0x9_0020_0000, our DTB, embedded initramfs
  -> busybox initramfs: USB CDC ACM gadget (2 serial ports: rootfs/shell + kernel log)
  -> send-rootfs.py: "SIZE TIME" + rootfs.sqfs -> tmpfs; squashfs + tmpfs overlay -> switch_root
  -> OpenRC -> 3a-hw service (firmware, display, GPU, DSPs, Wi-Fi, haptics)
            -> 3a-modem, 3a-sensors in the background -> tinydm -> Plasma Mobile
```

Firmware is never shipped here. The `3a-hw` service reads it at boot from the phone's own
partitions, read-only: `modem_a` (ADSP/CDSP/modem), `dsp_a`, `persist`, `bluetooth_a` and
`vendor_a` inside `super` (GPU, via `lp-map.py`).

## Building

Host: Windows with WSL Ubuntu (scripts use `/mnt/c/Users/...` paths, adjust them to yours).
Kernel sources: milos-mainline 7.2 + the Nura patch + `pmos3a/kernel/*.patch`.

1. Kernel and modules: `pmos3a/build-kernel.sh`, `build-modules.sh`, `build-extra-modules.sh`, `build-msm.sh`
2. DTB: `pmos3a/build-dtb.sh`; runtime overlays and small drivers: `pmos3a/display/build-*.sh`
3. hexagonrpcd with our fixes: `pmos3a/build-hexagonrpcd.sh`
4. rootfs: `pmos3a/build-rootfs.sh` once (postmarketOS + Alpine via apk.static), then
   `pmos3a/persist-live.sh` (services, rules, packages, UI choice; writes `out/rootfs.sqfs`)
5. initramfs: `pmos3a/build-initramfs.sh`, then the boot image: `pmos3a/make-boot.ps1`
   (must run after the initramfs, it patches the initrd end into the DTB)

Debug tools over the USB serial port: `phone-run.py`, `phone-shell.py`, `phone-push.py`, `phone-pull.py`;
`klog-pc.py` saves the live kernel log from the second port (survives hard hangs).

## Safety

Only `fastboot boot`. Never `fastboot flash`, never write to UFS: the scripts mount phone partitions
read-only and mark `super` read-only before mapping it. The speakers are left off until their
protection works (driving them without it can damage them).
