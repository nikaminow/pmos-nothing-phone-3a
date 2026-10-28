"""Print strings from an APK's resources.arsc that match a regex: arsc-strings.py app.apk 'regex'
Only the global string pool is parsed (UTF-8 or UTF-16), enough to find config values like
config_mainBuiltInDisplayCutout."""
import re, struct, sys, zipfile

arsc = zipfile.ZipFile(sys.argv[1]).read('resources.arsc')
pat = re.compile(sys.argv[2])
# table header (12 bytes), then the global string pool chunk
_, hsize, _, count, _, flags, start, _ = struct.unpack_from('<HHIIIIII', arsc, 12)
pool = 12
utf8 = flags & 0x100
offs = struct.unpack_from(f'<{count}I', arsc, pool + hsize)


def length(buf, pos, wide):
    if wide:
        n = struct.unpack_from('<H', buf, pos)[0]
        if n & 0x8000:
            return ((n & 0x7fff) << 16) | struct.unpack_from('<H', buf, pos + 2)[0], pos + 4
        return n, pos + 2
    n = buf[pos]
    if n & 0x80:
        return ((n & 0x7f) << 8) | buf[pos + 1], pos + 2
    return n, pos + 1


for o in offs:
    p = pool + start + o
    if utf8:
        _, p = length(arsc, p, False)
        n, p = length(arsc, p, False)
        s = arsc[p:p + n].decode('utf-8', 'replace')
    else:
        n, p = length(arsc, p, True)
        s = arsc[p:p + 2 * n].decode('utf-16-le', 'replace')
    if pat.search(s):
        print(s)
