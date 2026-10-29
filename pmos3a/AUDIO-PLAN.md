# Speakers on the Nothing Phone (3a): the "mega safe" plan

Smart amps drive the tiny speakers past their nominal rating and rely on the amp's speaker
protection (calibrated per phone). Without it, loud content can cook a voice coil. So: no sound
until protection is loaded and visible in the amp's registers, and hard volume caps everywhere.

## What we know
- Amps: 2x NXP TFA98xx at 0x34 / 0x35 on QUP1 SE6 (i2c@898000), reset gpio141 / gpio142
  (ABL DTB `tfa98xx@34/35`, compatible "tfa,tfa98xx"). Same bus, addresses and resets as the
  Phone (4a)'s AW88261 amps in Nura, so the board wiring is shared.
- Audio path (as on the 4a): LPASS -> Primary MI2S (gpio15 sck, 16 data0, 17 data1, 18 ws) ->
  amps, with IV feedback back over Primary MI2S TX. Nura's machine driver "qcom,milos-sndcard"
  is in our kernel; its AudioReach topology source is upstream-4a/audio/Nothing-Phone-4a.m4.
- WCD9378 codec (headset, mics, earpiece?) has no mainline driver: out of scope.
- Driver: NXP tfa98xx (GPL) is in Nothing's sm7635 kernel repo after all, under
  vendor/qcom/opensource/audio-kernel/asoc/codecs/tfa98xx (with TFA9873 B0 support; the mt6878
  tree's copy lacks the 9873). Built there with TFA_NON_DSP_SOLUTION: the driver only sets up the
  chip from the container; protection parameters reach the ADSP from userspace (misc device ->
  send_tfa_cal_apr, which on AudioReach platforms is a stub). Ported copy: pmos3a/audio/tfa98xx.
  Protection + profiles come from the container tfa98xx.cnt (vendor firmware), calibration from
  persist; both copied read-only.

## Stage A result (2026-10-29, read-only)
- Both amps answer on i2c@898000 (bus 2 on the phone) without touching their resets.
- REV (0x03) = 0x0b73 -> **TFA9873, revision B**; SYS_CTRL0 (0x00) = 0x4201, PWDN set (off).
- TFA9873 has **no DSP**: excursion/thermal speaker protection runs on the Qualcomm ADSP, in
  Nothing's AudioReach module from vendor `lib/rfsa/adsp/libtfadsp_rx.so` (+ `libtfadsp_tx.so`
  for IV feedback). The chip itself only has hardware thermal foldback / over-current shutdown.
  Container: vendor `firmware/tfa98xx.cnt`.
- So real protection needs the TFA DSP module in our topology (module ID, params and calibration
  from Nothing's ACDB / tfa98xx.cnt) - the hard part of stage B/C. Until then any test stays at
  very low gain with the chip's own limits only.

## Stage B result (2026-10-29)
- Ported driver (pmos3a/audio/tfa98xx, allow_start=0 gate) probes both amps, loads tfa98xx.cnt
  (fw-state Ok, mixer "TFA Profile"); sound card "Nothing-Phone-3a" (qcom,milos-sndcard, overlay
  3a-audio-i2c) registers with topology qcom/milos/Nothing-Phone-3a-tplg.bin. Amps stay PWDN.

## Android speaker graph (from QRD_acdb_cal.acdb, parsed with the audioreach-graphservices format)
- AMDB dynamic modules (CAPI v3, loaded on graph open): TFADSP RX 0x1700B911 (libtfadsp_rx.so,
  entry capi_tfadsp_rx), TFADSP TX 0x1700B912 (libtfadsp_tx.so, capi_tfadsp_tx). Goodix tfadsp 09.00.03.
- Speaker subgraph (DEVICERX=SPEAKER): ... SAL -> LOG -> TFA_RX -> SPLITTER -> LOG -> I2S sink
  (Primary MI2S, 48 kHz / 32 bit / 2 ch). IV subgraph (DEVICETX=VI_TX): I2S source (Primary MI2S
  TX) -> LOG -> SPLITTER -> TFA_TX (sink). RX and TX linked by a control link
  (APM_PARAM_ID_MODULE_CTRL_LINK_CFG) on port 0x80000000.
- Calibration: 18 params on TFA_RX (0x1800B920 enable, 0x1800B930..41: raw TFA DSP messages:
  selectors, speaker model, algo params, MBDRC, EQ, excursion filters, gains, senses, Re25C),
  TX only enable. Extracted blobs stay local in out/vendor-audio/extracted (proprietary).
- Needed in mainline: AMDB_CMD_REGISTER_MODULES at q6apm probe, APM_CMD_SET_CFG with the blobs
  for the TFA modules, the control link in the graph packet; topology with TFA_RX before the I2S
  sink and an IV subgraph on the same back end. Open risk: whether the ADSP can load the .so through
  our root-PD hexagonrpcd (Android may use a static audio PD).

## Stages
A. **No sound, no risk.** Enable i2c@898000 without any amp driver; release reset and only READ
   the revision register (amps power up in PWDN; no I2S clock = no sound possible). Copy
   tfa98xx.cnt and the speaker calibration read-only.
B. **Driver, still silent.** Port NXP tfa98xx to 7.2 as a module; it must load the container and
   calibration and report protection enabled in registers before any audio is sent.
C. **First sound.** Volume capped in three places: topology gain, ALSA softvol ceiling (-30 dB),
   amp profile. 1 kHz sine at -40 dBFS for 1 s, then read status (temperature, OCP, protection);
   raise level in small steps only with a clean status. No music / full volume before that.
D. **Daily use.** UCM like Nura's 4a, Phosh volume with a hard ceiling.
