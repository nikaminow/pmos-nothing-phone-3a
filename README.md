<div align="center">

# postmarketOS on the Nothing Phone (3a)

**Mainline Linux 7.2 + Plasma Mobile on the Nothing Phone (3a) "Asteroids" (SM7635 / milos)**

![Device](https://img.shields.io/badge/device-Nothing%20Phone%20(3a)-black?style=for-the-badge)
![SoC](https://img.shields.io/badge/SoC-SM7635%20milos-red?style=for-the-badge)
![Kernel](https://img.shields.io/badge/Linux-7.2%20mainline-yellow?style=for-the-badge&logo=linux&logoColor=white)
![UI](https://img.shields.io/badge/UI-Plasma%20Mobile-1d99f3?style=for-the-badge&logo=kde&logoColor=white)
![Boot](https://img.shields.io/badge/boot-RAM%20only-2ea44f?style=for-the-badge)

**English** · [Русский](README.ru.md)

[**⬇ Download**](../../releases/latest) · [Try it](#-try-it-no-flashing) · [Status](#-status) · [Known issues](#-known-issues) · [Roadmap](#-roadmap) · [Build](#-building) · [Dev log](PMOS-3A-PLAN.md)

</div>

> [!NOTE]
> It boots **from RAM only** (`fastboot boot`). Nothing is flashed: Android and all your data stay
> intact. Reboot the phone and you are back in Android.

Based on [Nura](https://github.com/UnderWeek/nura-nothing-phone-4a) for the Phone (4a) "Frogger" (same SoC),
kernel [milos-mainline](https://github.com/milos-mainline/linux) 7.2 with the Nura patch and our own patches.

## ✅ Status

| | Component | Notes |
|:-:|---|---|
| ✅ | Plasma Mobile, touch | status bar fitted around the camera hole, scale 2.7 |
| ✅ | Display, 120 Hz | msm DPU + DSI + panel-raydium-rm69220 (BOE BF068MWM-TD0) |
| ✅ | GPU (Adreno 810) | hardware OpenGL ES 3.2 (Mesa freedreno), firmware read from `vendor_a` |
| ✅ | All 7.4 GiB of RAM | memory map taken from the bootloader |
| ✅ | Wi-Fi, Bluetooth, hotspot | WCN6755 (ath11k + hci_uart) |
| ✅ | Modem: calls, SMS, mobile data | ModemManager over QRTR; EFS copied to RAM, served read-only |
| ✅ | Battery level | ADSP + `qcom_battmgr` |
| ✅ | Sensors: auto-rotate, light, proximity, compass | SSC on the ADSP via hexagonrpcd + iio-sensor-proxy |
| ✅ | Vibration | RT6010, own driver (strength: `rt6010_haptics.max_gain`) |
| ✅ | Glyph lights, flashlight | aw200xx |
| ✅ | Double-tap to wake | |
| ✅ | Clock | set from the PC at boot |
| 🚧 | Night light | kernel fix for the gamma LUT channel order, being tested |
| 🚧 | Speakers | amp driver and sound card work; speaker protection on the ADSP in progress ([AUDIO-PLAN.md](pmos3a/AUDIO-PLAN.md)) |
| 🚧 | Cameras | CAMSS port, see [CAMERA-PLAN.md](pmos3a/CAMERA-PLAN.md) |
| ❌ | Microphones, headset | WCD9378 has no mainline driver |
| ❌ | Suspend | disabled until resume works; the screen still turns off |
| ❌ | USB host / video out | |

Tested on the Phone (3a) only, not the (3a) Pro.

## 🚀 Try it (no flashing)

**You need:** an unlocked bootloader · [`fastboot`](https://developer.android.com/tools/releases/platform-tools) · Python 3.8+ · a USB cable.
From the [latest release](../../releases/latest), put `pmos-3a-boot.img`, `rootfs.sqfs` and `send-rootfs.py` in one folder.

1. **Bootloader:** `adb reboot bootloader`, or power off and hold <kbd>Power</kbd> + <kbd>Vol −</kbd>.
2. **Boot the image** (does not flash anything):
   ```sh
   fastboot boot pmos-3a-boot.img
   ```
   The splash stays on screen; the phone now appears as a USB serial port (18d1:d003).
3. **Send the system** (~900 MB, 2–3 minutes):

   | Windows | Linux |
   |---|---|
   | `python send-rootfs.py` | `sudo systemctl stop ModemManager`<br>`sudo python3 send-rootfs.py` |
   | COM port found automatically, no driver | or `--port /dev/ttyACM0` |

4. **Plasma Mobile** starts about a minute later. User `user`, password `147147`.

**Back to Android:** hold <kbd>Power</kbd> until it reboots. Partitions are only mounted read-only,
all changes live in RAM, nothing persists between boots.

<details>
<summary><b>Troubleshooting</b></summary>

- **`fastboot boot` fails:** the bootloader is locked, or fastboot is too old; update platform-tools.
- **No serial port:** wait 10–15 s after `fastboot boot`; try another USB cable or port.
- **Transfer stops or the phone reboots to Android:** start over from step 1. On Linux make sure
  ModemManager is stopped.
- **White or black screen after the transfer:** the display retries itself; give it a minute. If it
  stays, reboot and try again (the bootloader splash sometimes holds the display).
- Rule out a bad download: compare `sha256sum rootfs.sqfs` (Windows: `certutil -hashfile rootfs.sqfs SHA256`)
  with `SHA256SUMS.txt`.

</details>

## ⚠️ Known issues

- Swipe up and hold does not open the task switcher yet.
- Volume and notification popups open over the camera hole.
- No suspend: battery drains faster than on Android while the screen is off.
- Changes (Wi-Fi networks, apps, settings) are lost on reboot: everything lives in RAM.

## 🗺 Roadmap

- [x] Display, GPU, touch, Plasma Mobile
- [x] Wi-Fi, Bluetooth, modem, sensors, vibration, Glyph
- [x] Full RAM, correct clock, auto-rotate, double-tap wake
- [ ] Speakers with speaker protection (stage C of [AUDIO-PLAN.md](pmos3a/AUDIO-PLAN.md))
- [ ] Night light (fix being tested)
- [ ] Cameras ([CAMERA-PLAN.md](pmos3a/CAMERA-PLAN.md))
- [ ] Suspend / resume
- [ ] Installable image (flashable, keeps Android on the other slot)

## ⚙️ How it boots

```
fastboot boot pmos-3a-boot.img
  -> shim (shim.S + shimc.c): Linux at 0x9_0020_0000, our DTB, embedded initramfs
  -> busybox initramfs: USB CDC ACM gadget (2 serial ports: rootfs/shell + kernel log)
  -> send-rootfs.py: "SIZE TIME" + rootfs.sqfs -> tmpfs; squashfs + tmpfs overlay -> switch_root
  -> OpenRC -> 3a-hw (firmware, display, GPU, DSPs, Wi-Fi, haptics)
            -> 3a-modem, 3a-sensors in the background -> tinydm -> Plasma Mobile
```

> [!IMPORTANT]
> **No firmware is shipped.** At boot, `3a-hw` reads it read-only from the phone's own partitions:
> `modem_a`, `dsp_a`, `persist`, `bluetooth_a`, and `vendor_a` inside `super` (via `lp-map.py`).

## 🛠 Building

Host: Windows with WSL Ubuntu (scripts use `/mnt/c/Users/...` paths, adjust them to yours).
Kernel sources: milos-mainline 7.2 + the Nura patch + [`pmos3a/kernel/*.patch`](pmos3a/kernel).

| Step | Scripts |
|---|---|
| 1. Kernel, modules | `build-kernel.sh`, `build-modules.sh`, `build-extra-modules.sh`, `build-msm.sh` |
| 2. DTB, overlays, small drivers | `build-dtb.sh`, `display/build-*.sh` |
| 3. Audio | `audio/build-tfa98xx.sh` (amp driver), `audio/build-topology.sh` (AudioReach topology) |
| 4. hexagonrpcd with fixes | `build-hexagonrpcd.sh` |
| 5. rootfs | `build-rootfs.sh` once, then `persist-live.sh` → `out/rootfs.sqfs` |
| 6. initramfs → boot image | `build-initramfs.sh`, then `make-boot.ps1` (patches initrd end into the DTB) |

All scripts are in [`pmos3a/`](pmos3a). Debug over USB serial: `phone-run.py`, `phone-shell.py`,
`phone-push.py`, `phone-pull.py`; `klog-pc.py` records the live kernel log from the second port.

## 🛡 Safety

> [!WARNING]
> Only `fastboot boot`. Never `fastboot flash`, never write to UFS: the scripts mount phone partitions
> read-only and mark `super` read-only before mapping it. The speakers stay off until their
> protection works: the amp driver refuses to power them up (`allow_start=0`).

## 🙏 Credits

[Nura](https://github.com/UnderWeek/nura-nothing-phone-4a) (Phone (4a) port) ·
[milos-mainline](https://github.com/milos-mainline/linux) ·
[postmarketOS](https://postmarketos.org) · [KDE Plasma Mobile](https://plasma-mobile.org) ·
[linux-msm](https://github.com/linux-msm) (hexagonrpc, audioreach-topology) ·
NXP/Goodix tfa98xx and Nothing's kernel sources (GPL).
