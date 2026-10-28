/*
 * ABL -> mainline Linux shim (C part). ABL loads the boot image's ramdisk itself and
 * records it in its own DTB (/chosen linux,initrd-start/end). We pass Linux our DTB
 * instead, so copy those two values into it and add the ramdisk's range as a second
 * memory bank ("memory@0" placeholder, reg patched here): Linux only uses an initrd
 * that lies inside memory it knows. Returns the kernel entry point.
 */
typedef unsigned long u64;
typedef unsigned int u32;
typedef unsigned char u8;

static u32 be32(const u8 *p) { return (u32)p[0] << 24 | (u32)p[1] << 16 | (u32)p[2] << 8 | p[3]; }
static void put32(u8 *p, u32 v) { p[0] = v >> 24; p[1] = v >> 16; p[2] = v >> 8; p[3] = v; }
static u64 rdcells(const u8 *p, u32 len) { return len == 8 ? (u64)be32(p) << 32 | be32(p + 4) : be32(p); }
static void wr64(u8 *p, u64 v) { put32(p, v >> 32); put32(p + 4, (u32)v); }

static int streq(const char *a, const char *b)
{
	while (*a && *a == *b) { a++; b++; }
	return *a == *b;
}

/* Find property `name` in node `node` (name prefix match, depth 1); returns value ptr and len. */
static u8 *fdt_prop(u8 *fdt, const char *node, const char *name, u32 *len)
{
	if (be32(fdt) != 0xd00dfeed)
		return 0;
	u8 *st = fdt + be32(fdt + 8);
	const char *strs = (const char *)fdt + be32(fdt + 12);
	int depth = 0, in = 0;
	for (;;) {
		u32 tok = be32(st);
		st += 4;
		if (tok == 1) {
			const char *n = (const char *)st;
			u32 l = 0;
			while (n[l]) l++;
			depth++;
			if (depth == 2) {
				in = 1;
				for (u32 i = 0; node[i]; i++)
					if (n[i] != node[i]) { in = 0; break; }
			}
			st += (l + 4) & ~3u;
		} else if (tok == 2) {
			if (depth == 2) in = 0;
			depth--;
		} else if (tok == 3) {
			u32 l = be32(st), no = be32(st + 4);
			u8 *v = st + 8;
			if (in && depth == 2 && streq(strs + no, name)) { *len = l; return v; }
			st += 8 + ((l + 3) & ~3u);
		} else if (tok == 4) {
		} else {
			return 0;
		}
	}
}

u64 shim_c(u8 *abl, u8 *ours, u8 *ksrc, u64 ksize, u64 rdsize, u64 rdmagic, u8 *rdsrc)
{
	/* keep ABL's DTB for Linux (panel rails/GPIOs etc. live only there) */
	{
		u32 pl = 0;
		u8 *ph = fdt_prop(ours, "chosen", "abl-dtb", &pl);
		u32 al = be32(abl) == 0xd00dfeed ? be32(abl + 4) : 0;
		if (ph && al && al <= pl)
			for (u32 i = 0; i < al; i++)
				ph[i] = abl[i];
	}
	/* ramdisk embedded in our own image: point Linux at it in place (no copy) */
	if (rdsrc && rdsize) {
		u32 a = 0, b = 0, c = 0;
		u8 *os = fdt_prop(ours, "chosen", "linux,initrd-start", &a);
		u8 *oe = fdt_prop(ours, "chosen", "linux,initrd-end", &b);
		u8 *mr = fdt_prop(ours, "memory@0", "reg", &c);
		int ok = os && oe && mr && a == 8 && b == 8 && c == 16;
		if (ok) {
			u64 s = (u64)rdsrc, e = s + rdsize;
			wr64(os, s);
			wr64(oe, e);
			u64 ms = s & ~0x1fffffUL, me = (e + 0x1fffff) & ~0x1fffffUL;
			wr64(mr, ms);
			wr64(mr + 8, me - ms);
		}
		for (u32 y = 2300; y < 2390; y++)
			for (u32 x = 0; x < 1080; x++)
				((volatile u32 *)0xe3940000UL)[y * 1080 + x] = ok ? 0xff0000ff : 0xffff00ff;
		goto copy;
	}
	u32 l1 = 0, l2 = 0, l3 = 0, l4 = 0, l5 = 0;
	u8 *as = fdt_prop(abl, "chosen", "linux,initrd-start", &l1);
	u8 *ae = fdt_prop(abl, "chosen", "linux,initrd-end", &l2);
	u8 *os = fdt_prop(ours, "chosen", "linux,initrd-start", &l3);
	u8 *oe = fdt_prop(ours, "chosen", "linux,initrd-end", &l4);
	u8 *mr = fdt_prop(ours, "memory@0", "reg", &l5);
	/* status bar at the bottom of the splash (below the Linux console text) */
	u32 color = !(as && ae) ? 0xffff0000 : (os && oe && l3 == 8 && l4 == 8 && mr && l5 == 16) ? 0xff00ff00 : 0xffffff00;
	for (u32 y = 2300; y < 2390; y++)
		for (u32 x = 0; x < 1080; x++)
			((volatile u32 *)0xe3940000UL)[y * 1080 + x] = color;
	if (as && ae && os && oe && l3 == 8 && l4 == 8 && mr && l5 == 16) {
		u64 s = rdcells(as, l1), e = rdcells(ae, l2);
		/* ABL puts the vendor_boot ramdisk (lz4, unsupported here) first and ours
		 * right after it: keep only ours, the last rdsize bytes */
		/* boot v4: vendor ramdisk, ours, then bootconfig: find ours by its first 8 bytes */
		if (rdsize && e - s > rdsize) {
			for (u64 p = e - rdsize; p + 1 > s; p--) {
				const u8 *q = (const u8 *)p;
				u64 v = 0;
				for (int i = 7; i >= 0; i--)
					v = v << 8 | q[i];
				if (v == rdmagic) {
					s = p;
					e = p + rdsize;
					break;
				}
			}
		}
		wr64(os, s);
		wr64(oe, e);
		u64 ms = s & ~0x1fffffUL, me = (e + 0x1fffff) & ~0x1fffffUL;
		wr64(mr, ms);
		wr64(mr + 8, me - ms);
	}
copy:
	/* Linux to 0x9_0020_0000 + text_offset (start of its main bank) */
	u64 *dst = (u64 *)(0x900200000UL + *(u64 *)(ksrc + 8));
	u64 *src = (u64 *)ksrc;
	for (u64 i = 0; i < ksize / 8 + 1; i++)
		dst[i] = src[i];
	return (u64)(0x900200000UL + *(u64 *)(ksrc + 8));
}
