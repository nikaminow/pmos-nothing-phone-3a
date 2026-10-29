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
- Driver: NXP tfa98xx (GPL) is not in Nothing's sm7635 kernel repo, but in other Nothing trees,
  newest in NothingOSS/android_kernel_device_modules_6.1_nothing_mt6878 (sound/soc/codecs/tfa98xx).
  Protection + profiles come from the container tfa98xx.cnt (vendor firmware), calibration from
  persist; both copied read-only.

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
