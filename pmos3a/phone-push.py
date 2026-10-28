"""Copy files from the PC to the 3a over USB serial: phone-push.py local_file /path/on/phone [...]"""
import base64, ctypes, gzip, hashlib, msvcrt, subprocess, sys, time
from ctypes import wintypes

ps = "(Get-PnpDevice -PresentOnly -Class Ports | ? { $_.InstanceId -match 'VID_18D1' -and $_.InstanceId -notmatch 'MI_02' } | Select -First 1).FriendlyName"
name = subprocess.run(['powershell', '-NoProfile', '-Command', ps], capture_output=True, text=True).stdout
port = name[name.find('(COM') + 1:name.find(')', name.find('(COM'))]
f = open(r'\\.\%s' % port, 'r+b', buffering=0)


class CT(ctypes.Structure):
    _fields_ = [(n, wintypes.DWORD) for n in ('ri', 'rm', 'rc', 'wm', 'wc')]


ctypes.windll.kernel32.SetCommTimeouts(msvcrt.get_osfhandle(f.fileno()), ctypes.byref(CT(0xFFFFFFFF, 0, 0, 0, 120000)))


def drain(wait):
    out, t0 = b'', time.time()
    while time.time() - t0 < wait:
        b = f.read(1 << 16)
        out += b
        if not b:
            time.sleep(0.05)
    return out


def until(mark, wait):
    out, t0 = b'', time.time()
    while mark not in out and time.time() - t0 < wait:
        b = f.read(1 << 16)
        out += b
        if not b:
            time.sleep(0.05)
    return out


f.write(b"\x03\nstty -echo; PS2=''\n")
drain(1)
args = sys.argv[1:]
CHUNK = 256 * 1024   # base64 bytes per heredoc: a failed push stops at a chunk, not mid-file
for local, remote in zip(args[0::2], args[1::2]):
    raw = open(local, 'rb').read()
    data = base64.encodebytes(gzip.compress(raw))
    f.write(b': > /tmp/.push.b64\n')
    for c in range(0, len(data), CHUNK):
        part = data[c:c + CHUNK]
        f.write(b"cat >> /tmp/.push.b64 <<'@@EOF@@'\n")
        for i in range(0, len(part), 4096):   # base64 lines are 76 chars: under the tty line limit
            f.write(part[i:i + 4096])
            drain(0.02)   # keep reading: an unread phone tty blocks the shell, then our write times out
        f.write(f'@@EOF@@\necho chunk{c}\n'.encode())
        if f'chunk{c}'.encode() not in until(f'chunk{c}'.encode(), 30):
            sys.exit(f'{local}: no ack for chunk at {c}/{len(data)}')
        print(f'\r{local}: {min(c + CHUNK, len(data)) * 100 // len(data)}%', end='', flush=True)
    f.write(f'base64 -d /tmp/.push.b64 | gunzip > {remote} && rm /tmp/.push.b64; '
            f'echo pushed $(md5sum < {remote})\n'.encode())
    got = until(b'pushed', 30).decode('utf-8', 'replace')
    ok = hashlib.md5(raw).hexdigest() in got
    print(f'\n{remote}: {"OK" if ok else "MD5 MISMATCH " + got.strip()[-80:]}')
    if not ok:
        sys.exit(1)
f.write(b'stty echo\n')
