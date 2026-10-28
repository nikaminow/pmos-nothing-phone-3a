"""Save the 3a's live kernel log (second USB serial port, MI_02) to a file: klog-pc.py [out.log]
Reconnects across phone reboots; each boot is appended after a "=== port opened" marker."""
import ctypes, msvcrt, os, subprocess, sys, time
from ctypes import wintypes

out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out', 'klog.log')
ps = ("(Get-PnpDevice -PresentOnly -Class Ports | ? { $_.InstanceId -match 'VID_18D1' -and "
      "$_.InstanceId -match 'MI_02' } | Select -First 1).FriendlyName")


class CT(ctypes.Structure):
    _fields_ = [(n, wintypes.DWORD) for n in ('ri', 'rm', 'rc', 'wm', 'wc')]


def port():
    name = subprocess.run(['powershell', '-NoProfile', '-Command', ps], capture_output=True, text=True).stdout
    return name[name.find('(COM') + 1:name.find(')', name.find('(COM'))] if '(COM' in name else None


with open(out, 'ab', buffering=0) as log:
    while True:
        p = port()
        if not p:
            time.sleep(2)
            continue
        try:
            with open(r'\\.\%s' % p, 'rb', buffering=0) as s:
                # return as soon as bytes arrive, or empty after 1 s (the port stays open)
                ctypes.windll.kernel32.SetCommTimeouts(msvcrt.get_osfhandle(s.fileno()),
                                                       ctypes.byref(CT(0xFFFFFFFF, 0xFFFFFFFF, 1000, 0, 0)))
                log.write(f'\n=== port opened {time.strftime("%H:%M:%S")} {p}\n'.encode())
                while True:
                    log.write(s.read(4096) or b'')
        except OSError:
            time.sleep(1)
