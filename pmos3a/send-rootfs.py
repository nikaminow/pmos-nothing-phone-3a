"""Send out/rootfs.tar.gz to the 3a initramfs over its USB serial port (CDC ACM, VID 18d1 PID d003)."""
import os, subprocess, sys
p = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out', 'rootfs.tar.gz')
ps = "(Get-PnpDevice -PresentOnly -Class Ports | ? InstanceId -match 'VID_18D1&PID_D003').FriendlyName"
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
    s.write(f'{total}\n'.encode())
    n = 0
    import time
    # 16 KiB + 2 ms (~8 MB/s), verified (md5 matched); 32 KiB lost data, unthrottled too
    while b := f.read(1 << 14):
        s.write(b)
        time.sleep(0.002)
        n += len(b)
        print(f'\r{n >> 20}/{total >> 20} MiB', end='', flush=True)
print('\ndone: the phone unpacks it and starts Plasma Mobile')
