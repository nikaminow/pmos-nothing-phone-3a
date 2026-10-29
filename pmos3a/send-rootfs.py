"""Send out/rootfs.tar.gz (or the given tarball) to the 3a initramfs over its USB serial port
(CDC ACM, VID 18d1 PID d003): send-rootfs.py [rootfs.tar.gz]"""
import os, subprocess, sys, time
out =os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out')
# default: the squashfs rootfs (initramfs mounts it + overlay), else the old tar.gz
p = sys.argv[1] if len(sys.argv) > 1 else next(
    (os.path.join(out, f) for f in ('rootfs.sqfs', 'rootfs.tar.gz') if os.path.exists(os.path.join(out, f))))
ps = "(Get-PnpDevice -PresentOnly -Class Ports | ? { $_.InstanceId -match 'VID_18D1&PID_D003' -and $_.InstanceId -notmatch 'MI_02' } | Select -First 1).FriendlyName"
name = subprocess.run(['powershell', '-NoProfile', '-Command', ps], capture_output=True, text=True).stdout
port = name[name.find('(COM') + 1:name.find(')', name.find('(COM'))] if '(COM' in name else None
if not port:
    sys.exit('no COM port for the phone (18d1:d003): is it booted into the initramfs?')
import hashlib
total = os.path.getsize(p)
h = hashlib.md5()
with open(p, 'rb') as f:
    while b := f.read(1 << 24):
        h.update(b)
print(f'{port}: sending {total >> 20} MiB, md5 {h.hexdigest()[:12]} (compare with the phone)')
with open(r'\\.\%s' % port, 'wb', buffering=0) as s, open(p, 'rb') as f:
    # "SIZE UNIXTIME": the PMIC RTC is read-only to us and Android keeps the offset in its data,
    # so the phone would start at 1970; the initramfs sets the clock from the PC
    s.write(f'{total} {int(time.time())}\n'.encode())
    n = 0
    # 16 KiB + 2 ms (~8 MB/s), verified (md5 matched); 32 KiB lost data, unthrottled too
    while b := f.read(1 << 14):
        s.write(b)
        time.sleep(0.002)
        n += len(b)
        print(f'\r{n >> 20}/{total >> 20} MiB', end='', flush=True)
print('\ndone: the phone mounts it and starts the UI')
