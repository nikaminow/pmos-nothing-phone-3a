"""Send the rootfs to the 3a initramfs over its USB serial port (CDC ACM, VID 18d1 PID d003):
send-rootfs.py [rootfs.sqfs] [--port COM5 | --port /dev/ttyACM0]
Windows: COM port found automatically. Linux: /dev/ttyACM* found automatically (needs access
to it: sudo, or the dialout/uucp group; stop ModemManager first, it probes new serial ports)."""
import glob, hashlib, os, subprocess, sys, time
args = sys.argv[1:]
port = None
if '--port' in args:
    i = args.index('--port')
    port = args[i + 1]
    del args[i:i + 2]
here = os.path.dirname(os.path.abspath(__file__))
# default: the squashfs rootfs (initramfs mounts it + overlay), else the old tar.gz; looks next
# to this script (release download) and in out/ (build tree)
p = args[0] if args else next((f for d in (here, os.path.join(here, 'out'))
                               for f in (os.path.join(d, 'rootfs.sqfs'), os.path.join(d, 'rootfs.tar.gz'))
                               if os.path.exists(f)), None)
if not p:
    sys.exit('rootfs.sqfs not found: pass its path')


def find_port():
    if os.name == 'nt':
        ps = "(Get-PnpDevice -PresentOnly -Class Ports | ? { $_.InstanceId -match 'VID_18D1&PID_D003' -and $_.InstanceId -notmatch 'MI_02' } | Select -First 1).FriendlyName"
        name = subprocess.run(['powershell', '-NoProfile', '-Command', ps], capture_output=True, text=True).stdout
        return name[name.find('(COM') + 1:name.find(')', name.find('(COM'))] if '(COM' in name else None
    # Linux: the first ACM interface (00) of 18d1:d003; interface 02 is the kernel log
    for t in sorted(glob.glob('/sys/class/tty/ttyACM*')):
        intf = os.path.realpath(os.path.join(t, 'device'))
        try:
            vid = open(os.path.join(intf, '..', 'idVendor')).read().strip()
            pid = open(os.path.join(intf, '..', 'idProduct')).read().strip()
            num = open(os.path.join(intf, 'bInterfaceNumber')).read().strip()
        except OSError:
            continue
        if (vid, pid, num) == ('18d1', 'd003', '00'):
            return '/dev/' + os.path.basename(t)


port = port or find_port()
if not port:
    sys.exit('no serial port for the phone (18d1:d003): is it booted into the initramfs?')
total = os.path.getsize(p)
h = hashlib.md5()
with open(p, 'rb') as f:
    while b := f.read(1 << 24):
        h.update(b)
print(f'{port}: sending {total >> 20} MiB, md5 {h.hexdigest()[:12]} (compare with the phone)')
dev = r'\\.\%s' % port if os.name == 'nt' else port
with open(dev, 'wb' if os.name == 'nt' else 'r+b', buffering=0) as s, open(p, 'rb') as f:
    if os.name != 'nt':
        # raw tty: the default line discipline would turn \n into \r\n inside the image
        import termios, tty
        tty.setraw(s.fileno())
        a = termios.tcgetattr(s.fileno())
        a[2] |= termios.CLOCAL
        termios.tcsetattr(s.fileno(), termios.TCSANOW, a)
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
