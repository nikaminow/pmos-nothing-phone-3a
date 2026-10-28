"""Where a logical partition lies inside Android's super: lp-map.py /dev/sdX vendor_a
Reads the LP metadata only (never writes). Prints one "byte_offset byte_size" line per extent."""
import struct, sys

dev, want = sys.argv[1], sys.argv[2]
with open(dev, 'rb') as f:
    f.seek(4096)
    magic, _, _, meta_max = struct.unpack('<II32sI', f.read(44))
    assert magic == 0x616C4467, 'no LP geometry'
    f.seek(4096 + 2 * 4096)   # primary metadata, slot 0
    h = f.read(256)
    magic, major, minor, hsize = struct.unpack_from('<IHHI', h)
    assert magic == 0x414C5030, 'no LP metadata header'
    # table descriptors (offset, num, entry_size) after header checksum and tables size/checksum
    parts, exts = struct.unpack_from('<III', h, 80), struct.unpack_from('<III', h, 92)
    f.seek(4096 + 2 * 4096 + hsize)
    tables = f.read(meta_max)
for i in range(parts[1]):
    e = tables[parts[0] + i * parts[2]:][:parts[2]]
    name = e[:36].rstrip(b'\0').decode()
    _, first, num = struct.unpack_from('<III', e, 36)
    if name != want:
        continue
    for j in range(first, first + num):
        x = tables[exts[0] + j * exts[2]:][:exts[2]]
        sectors, ttype, sector = struct.unpack_from('<QIQ', x)
        assert ttype == 0, 'zero extent'
        print(sector * 512, sectors * 512)
    break
else:
    sys.exit(f'{want}: not in super')
