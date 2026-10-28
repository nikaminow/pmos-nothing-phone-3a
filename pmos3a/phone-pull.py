"""Copy a file from the 3a to the PC over USB serial: phone-pull.py /path/on/phone local_file"""
import base64, ctypes, msvcrt, subprocess, sys, time
from ctypes import wintypes

ps = "(Get-PnpDevice -PresentOnly -Class Ports | ? InstanceId -match 'VID_18D1').FriendlyName"
name = subprocess.run(['powershell', '-NoProfile', '-Command', ps], capture_output=True, text=True).stdout
port = name[name.find('(COM') + 1:name.find(')', name.find('(COM'))]
f = open(r'\\.\%s' % port, 'r+b', buffering=0)


class CT(ctypes.Structure):
    _fields_ = [(n, wintypes.DWORD) for n in ('ri', 'rm', 'rc', 'wm', 'wc')]


ctypes.windll.kernel32.SetCommTimeouts(msvcrt.get_osfhandle(f.fileno()), ctypes.byref(CT(0xFFFFFFFF, 0, 0, 0, 2000)))
f.write(b'\x03\n')
time.sleep(0.5)
f.read(1 << 20)
# markers built by the shell so the echoed command line does not match them
# markers use '@', which base64 never contains ("END" can occur in the data itself)
f.write(('stty -echo; echo @@B""EGIN@@; gzip -c %s | base64; echo @@E""ND@@; stty echo\n' % sys.argv[1]).encode())
out, t0 = b'', time.time()
while b'@@END@@' not in out.split(b'@@BEGIN@@', 1)[-1] and time.time() - t0 < 300:
    b = f.read(1 << 16)
    out += b
    if not b:
        time.sleep(0.05)
body = out.split(b'@@BEGIN@@', 1)[1].split(b'@@END@@', 1)[0]
import gzip
data = gzip.decompress(base64.b64decode(b''.join(body.split())))
open(sys.argv[2], 'wb').write(data)
print(f'{sys.argv[2]}: {len(data)} bytes')
