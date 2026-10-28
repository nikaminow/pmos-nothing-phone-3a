# postmarketOS (Nura) on Nothing Phone (3a) "Asteroids" — plan / handoff

Base: `upstream-4a/` = Nura, postmarketOS + Plasma Mobile for Nothing Phone (4a) "Frogger".
Same SoC (SM7635 / milos), so ~90% is reusable. Boot is RAM-only, nothing flashed.

## Hard rules
- Only `fastboot boot`. Never `fastboot flash`, never write userdata/UFS (user data must survive).
- adb: read-only. PC is Windows; Git Bash fork broken -> PowerShell; Linux builds in WSL Ubuntu
  (`wsl -u root`, put commands in script files, quoting breaks inline).

## Boot chain (from upstream-4a/README.md)
fastboot boot nura-boot.img
 -> stage1: Nothing downstream 6.1 kernel + initramfs (stage1/nura-init)
 -> kexec stage2: mainline milos 7.2 kernel + DTB + stage2.gz
 -> PC sends rootfs.tar.gz over USB ethernet (tools/send-rootfs.py) -> tmpfs -> switch_root -> Plasma Mobile

## RESULT 2026-10-27
`fastboot boot nura-boot-v57.img` (4a release) on the 3a: hangs on the Nothing logo => 4a stage1 kernel
does not run on 3a. **New plan: skip stage1.** ABL boots our own kernels directly (probe, XNU worked),
so build the mainline milos kernel (github.com/milos-mainline/linux, commit in upstream-4a/kernel/BASE_COMMIT,
+ nura patch) with a new `milos-nothing-asteroids.dts` (simple-framebuffer at 0xE3940000 1080x2392 stride 4320,
`console=tty0`, USB gadget, touch on spi0) and the stage2 initramfs, wrap with mkbootimg v4
(kernel Image.gz + appended DTB or v4 dtb), then `fastboot boot`. First goal: kernel console visible.

## MILESTONE 2026-10-27 evening: mainline Linux boots fully on the 3a
pmos3a/out/pmos-3a-boot.img (shim.S copies Image to 0x9_0020_0000 and passes our DTB;
memory = only the 4 GiB bank 0x9_0000_0000; bootargs console=tty0 ignore_loglevel clk_ignore_unused
pd_ignore_unused arm-smmu.disable_bypass=0 panic=0 regulator_ignore_unused; ramoops at 0x9_FFF0_0000):
8 CPUs, cpufreq/EM, fbcon on simple-framebuffer (penguins visible), runs to
"Please append a correct root= boot option" -> VFS panic (no initramfs yet). Screen turns white
only at the panic. Log reading: Springboard (springboard/src/kernel/pstore.rs) shows ramoops or the
printk text found in RAM after Power+VolDown -> bootloader (not Android).
DTB edits without kernel tree: pmos3a/add-arg.sh, pmos3a/patch-dtb.sh (dtc in WSL).
Next: initramfs (busybox, USB gadget networking like Nura stage2), enable usb_1 as peripheral in DTS
(copy Nura 4a usb/phy nodes), then send-rootfs and Plasma Mobile.

## WORKS 2026-10-28: Plasma Mobile with touch on the 3a (RAM only)
Run: fastboot boot pmos3a/out/pmos-3a-boot.img -> busybox initramfs (USB CDC ACM, COM port) ->
python pmos3a/send-rootfs.py (rootfs.tar.gz, 16 KiB+2 ms chunks, faster loses data) -> switch_root
-> OpenRC -> tinydm -> Plasma Mobile (QPainter, simpledrm). Shell: pmos3a/phone-shell.py,
scripted: pmos3a/phone-run.py 'cmd' [secs]. Kernel: SPI_QCOM_GENI=y, all modules in rootfs,
blacklist in /etc/modprobe.d/3a-blacklist.conf (display/GPU/video/camera/remoteproc/audio).
Pitfalls: KWIN_DRM_NO_AMS=1 => "Failed to find a working output layer" (black screen);
ABL hangs on a 575 MB kernel and its ramdisk field did not deliver ours; shim (shim.S+shimc.c)
points Linux at the initramfs embedded after the kernel, no copy.
Next: read firmware from UFS (mount -o ro modem_a; never write), battery (ADSP), GPU, Wi-Fi.

## STATE 2026-10-28 evening (continue here)
Public repo: github.com/nikaminow/pmos-nothing-phone-3a (root = nura-3a, .gitignore whitelists pmos3a/ + this file;
no blobs/ABL dump/binaries). Boot: Power+VolDown -> fastboot boot out/pmos-3a-boot.img -> send-rootfs.py.
UI: **Phosh** (greetd + phrog), Plasma backup out/rootfs-plasma.tar.gz. Everything below is in 3a-hw / persist-live.sh.
Works: display + **GPU** (Adreno 810, OpenGL ES 3.2, kmscube 120 fps; firmware gen80300_* from vendor_a in super
via lp-map.py + dm-linear --readonly + erofs ro), **Wi-Fi** (ath11k, internet OK), **Bluetooth**, **modem**
(LTE, MegaFon, mobile data via qmapmux0.0 with APN internet), battery, touch, CPU, cutout layout (gmobile).
Key fixes / pitfalls (details in git log):
- Display first bind always fails (ABL splash still scanning when SMMU attaches); 3a-hw unbinds/rebinds mdss.
  The rebind needed: devcoredump disabled (devcd_del UAF), kernel patch pmos3a/kernel/0001 (msm never
  cleaned DPU self-refresh work -> Oops) via build-msm.sh; GPU overlay (3a-gpu) only before the 2nd bind.
  3a-splash-off.ko (INTF_1 0xae36000+0x6c) reads 0 -> no effect; real splash handover still open.
- q6v5_pas + ath11k blacklisted for udev (no firmware yet at autoload); 3a-hw loads them in order.
- WCN6755 RF powered by the wcn6750-pmu pwrseq (4a block + S1J rail on PMR735B gpio1, RF_CLK1, sleep clk
  PMK8550 gpio5, BT uart11); 3a-wlan-pwr.ko holds the "wlan" target (else no TX with BT off); BD address
  from SoC serial (hci0 stayed unconfigured); Wi-Fi calibration = modem_a qca6750/bdwlan.elf (board_id 0xff).
- polkit: seatless session -> rule 50-3a-user.rules (netdev/plugdev).
- Modem: EFS copied to RAM, rmtfs -o /var/lib/rmtfs -r (never writes UFS); IPA overlay 3a-modem; SIM
  provisioning slot2 primary / slot1 secondary; ModemManager must be killed by pid (pkill -x misses it).
- Debug: second USB serial port (COM MI_02) carries /dev/kmsg; run `python pmos3a/klog-pc.py` on the PC
  -> out/klog.log. Hangs end in a Gunyah reboot to Android, which overwrites ramoops.
Not done (higher risk / big): audio (3a has NXP TFA98xx amps @0x34/0x35 + WCD9378 codec, unlike 4a's
AW88261; no mainline driver for WCD9378, TFA needs speaker-protection config -> risk to speakers),
camera, sensors (ADSP SSC), haptics (rt6010). Easy next: Glyph LEDs (aw20036 @0x3a, mainline leds-aw200xx).

## STATE end of 2026-10-28 night
Working live and persisted in rootfs (pmos3a/persist-live.sh -> out/rootfs.tar.gz, service /etc/init.d/3a-hw):
- real display: msm DPU + DSI + panel-raydium-rm69220 (BOE BF068MWM-TD0, from mainline), 120 Hz,
  overlay pmos3a/display/3a-display.dtbo applied by 3a-ovl.ko (build-display.sh). Panel wiring from
  ABL DTB (shim copies it to /proc/device-tree/chosen/abl-dtb; pmos3a/abl.dts): reset gpio12,
  vddio L9B, dvdd fixed reg gpio109, vci L19B; same as Phone (4a).
- CPU governor performance (A720 were stuck at 480 MHz).
- firmware: modem_a (sde6) mounted READ-ONLY, pil-squash.py -> /lib/firmware/qcom/milos/nothing/asteroids;
  ADSP + CDSP running, battery via qcom_battmgr (shows 65%).
- KWin scale 3.1 (kwinoutputconfig.json), QT_QUICK_BACKEND=software must stay (plasmashell crashes without).
Open: icons on the homescreen not drawn (software Qt Quick; expect fix with GPU).
Next, low to high risk: Wi-Fi (WPSS started OK; overlay display/3a-wifi.dtbo + 3a-ovl-wifi.ko built,
  firmware display/ath11k-wcn6750.tgz not pushed yet: phone-push.py failed on the 6.6 MB file, write
  PermissionError -> push in smaller files or fix), Bluetooth, GPU (gen80300 sqe/gmu/zap from vendor in
  super sda6, parse LP metadata read-only), modem, audio (risky: amps), camera.
Tools: phone-run.py ('cmd' or '-' + stdin), phone-shell.py, phone-pull.py, phone-push.py (COM port).

## NEXT (state at end of 2026-10-27, limit ran out)
- DONE: upstream milos-mainline has a real 3a DTS (milos-nothing-asteroids.dts: regulators, USB,
  simplefb with interconnects so the screen stays on). pmos3a/milos-nothing-asteroids-ram.dts
  includes it + 4 GiB memory, bootargs, initrd 0x9_1000_0000, usb_1 dr_mode=peripheral.
  Build: WSL `bash pmos3a/build-dtb.sh` (sparse DT sources in /root/dts) -> out/milos-nothing-asteroids.dtb.
  NOT yet booted with this DTB. First test: make-boot.ps1, fastboot boot, expect screen to stay on.
- TODO 1: shim.S: also copy an appended initramfs to 0x9_1000_0000 (add rd_off/rd_size words like
  k_off/k_size, make-boot.ps1 appends it and patches /chosen linux,initrd-end with fdtput).
- TODO 2: initramfs = busybox (Alpine aarch64 busybox-static apk) + /init: mount proc/sys/dev,
  configfs NCM gadget on usb_1, ip 172.16.42.1, telnetd; or reuse Nura stage2/nura-init.
- TODO 3: Nura flow: tools/send-rootfs.py rootfs.tar.gz over USB -> switch_root -> Plasma Mobile
  (scripts/build-rootfs.sh; firmware pulled read-only from the 3a).

## Steps (original)
1. **Try stage1 as is.** Download `nura-boot-v57.img` (Nura Releases), `fastboot boot` it on the 3a.
   Nothing ships one downstream kernel tree for volcano; if the console appears, stage1 works.
   If it hangs/reboots: rebuild stage1 from Nothing's 3a kernel source (github.com/NothingOSS).
2. **3a DTS for stage2.** Copy `milos-nothing-frogger.dts` (in kernel/nura-frogger-milos-7.2.patch)
   -> `milos-nothing-asteroids.dts`:
   - Display: 3a panel differs from 4a NT37706A. First use **simple-framebuffer** on the ABL splash:
     reg 0xE3940000, size 0x2B00000, 1080x2392, stride 4320, a8r8g8b8 (verified by our probe).
     Remove the panel/mdss overlay (nura-ovl) for now. Real panel driver later (read /sys/class/drm,
     panel name from `adb shell cat /proc/cmdline` or dmesg on Android).
   - Touch: keep focaltech ft3683g on spi0, IRQ gpio19, reset gpio20, vci L22B, vddio L11B —
     **verify on 3a** (`adb shell ls /proc/device-tree/soc/spi@a80000`, read child node props:
     interrupts, reset gpio, *-supply). Set touchscreen-size-x/y from the 3a node.
   - Disable audio amps (AW88261, may differ / damage speakers), keep UFS, USB, Wi-Fi (check WCN chip).
   - Memory/reserved-memory: compare with 3a ABL DTB (probe: 13 ranges, gunyah at 0x80000000).
3. Build kernel + DTB in WSL: `scripts/` of upstream-4a (kernel config `kernel/config-milos.aarch64`).
   Put the new DTS into arch/arm64/boot/dts/qcom/ and the Makefile.
4. stage2 initramfs: point to the asteroids DTB in stage1/nura-init kexec command.
5. Rootfs: `scripts/build-rootfs.sh` with firmware from the 3a (`adb pull /vendor/firmware_mnt`,
   `/vendor/firmware` — read only). GPU firmware is the same Adreno 810 (a8xx) family.
6. Boot: `tools/boot.sh` (Mac/Linux). On Windows: run from WSL with usbipd, or port to PowerShell:
   `fastboot boot nura-boot.img` then `python tools/send-rootfs.py rootfs.tar.gz` over the RNDIS interface.

## Known 3a facts (from our probe and Android)
SoC SM7635, A520x4 + A720x4, EL1 under Gunyah, GICv3 GICR stride 0x40000, PSCI smc,
fb splash 0xE3940000, RAM 7.6 GiB, fastboot max-download 768 MB, touch fts_ts on spi0 (SE0 0xa80000) IRQ gpio19.
Reference sources: `ref-linux/` (milos.dtsi, gcc, pinctrl, geni, rpmh).

## Related
- `../springboard/` — own Rust OS attempt (paused). `ios-topaz/` — iOS port (XNU reaches launchd).
