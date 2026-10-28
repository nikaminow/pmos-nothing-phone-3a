"""Run shell commands on the 3a over USB serial and print the output: phone-run.py "cmd; cmd" [seconds]"""
import ctypes, msvcrt, subprocess, sys, time
from ctypes import wintypes

ps = "(Get-PnpDevice -PresentOnly -Class Ports | ? InstanceId -match 'VID_18D1').FriendlyName"
name = subprocess.run(['powershell', '-NoProfile', '-Command', ps], capture_output=True, text=True).stdout
port = name[name.find('(COM') + 1:name.find(')', name.find('(COM'))]
f = open(r'\\.\%s' % port, 'r+b', buffering=0)


class CT(ctypes.Structure):
    _fields_ = [(n, wintypes.DWORD) for n in ('ri', 'rm', 'rc', 'wm', 'wc')]


ctypes.windll.kernel32.SetCommTimeouts(msvcrt.get_osfhandle(f.fileno()), ctypes.byref(CT(0xFFFFFFFF, 0, 0, 0, 2000)))
f.write(b'\x03\n')   # Ctrl+C: free the shell if an earlier command still runs
time.sleep(0.5)
f.read(65536)
# "-": command from stdin (Windows argv parsing eats double quotes)
cmd = sys.stdin.read().lstrip('﻿').strip() if sys.argv[1] == '-' else sys.argv[1]
f.write((cmd + '; echo __END__\n').encode())
out, t0 = b'', time.time()
while time.time() - t0 < float(sys.argv[2] if len(sys.argv) > 2 else 10):
    b = f.read(65536)
    if b:
        out += b
        if out.count(b'__END__') >= 2:
            break
    else:
        time.sleep(0.05)
sys.stdout.write(out.decode('utf-8', 'replace'))
