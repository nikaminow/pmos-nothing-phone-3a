"""Shell on the 3a over its USB serial port. Type a command + Enter; Ctrl+C quits."""
import ctypes, msvcrt, subprocess, sys, threading, time
from ctypes import wintypes

ps = "(Get-PnpDevice -PresentOnly -Class Ports | ? InstanceId -match 'VID_18D1').FriendlyName"
name = subprocess.run(['powershell', '-NoProfile', '-Command', ps], capture_output=True, text=True).stdout
if '(COM' not in name:
    sys.exit('no COM port for the phone')
port = name[name.find('(COM') + 1:name.find(')', name.find('(COM'))]
f = open(r'\\.\%s' % port, 'r+b', buffering=0)


class COMMTIMEOUTS(ctypes.Structure):
    _fields_ = [(n, wintypes.DWORD) for n in ('ri', 'rm', 'rc', 'wm', 'wc')]


# reads return at once: a blocking ReadFile would hold the handle and stall our writes
h = msvcrt.get_osfhandle(f.fileno())
ctypes.windll.kernel32.SetCommTimeouts(h, ctypes.byref(COMMTIMEOUTS(0xFFFFFFFF, 0, 0, 0, 2000)))
lock = threading.Lock()


def pump():
    while True:
        with lock:
            b = f.read(4096)
        if b:
            sys.stdout.write(b.decode('utf-8', 'replace'))
            sys.stdout.flush()
        else:
            time.sleep(0.05)


threading.Thread(target=pump, daemon=True).start()
print(f'{port}: phone shell, type commands here (try: tail -30 /var/log/tinydm.log)')
with lock:
    f.write(b'\n')
try:
    for line in sys.stdin:
        with lock:
            f.write(line.replace('\r', '').encode())
except KeyboardInterrupt:
    pass
