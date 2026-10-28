"""Patch hexagonrpcd (v0.4.0) so DSP writes are accepted and dropped: hexagonrpcd-dropwrites.py SRC_DIR
The 3a's SSC rewrites sensors/registry/DIR at every start; upstream hexagonrpcd refuses any write
(AEE_EUNSUPPORTED) and the sensors PD stops. The served tree is a RAM copy, so dropping is right."""
import re, sys

src = sys.argv[1]
d = f'{src}/hexagonrpcd/interfaces/apps_std.def'
s = open(d).read()
s = s.replace('HEXAGONRPC_DEFINE_REMOTE_METHOD(4, apps_std_fread, 1, 0, 2, 1)\n',
              'HEXAGONRPC_DEFINE_REMOTE_METHOD(4, apps_std_fread, 1, 0, 2, 1)\n'
              'HEXAGONRPC_DEFINE_REMOTE_METHOD(5, apps_std_fwrite, 1, 1, 2, 0)\n', 1)
open(d, 'w').write(s)

c = f'{src}/hexagonrpcd/apps_std.c'
s = open(c).read()
n = len(s)

s = s.replace('static const int apps_std_whence_table[] = {', '''/*
 * Writes from the DSP (the sensors core rewrites its registry index at every start) get a
 * "sink" descriptor: the data is accepted and dropped, the served tree stays as it is.
 */
#define APPS_STD_SINK_FD_BASE 0x10000
#define APPS_STD_SINK_FDS 32
static uint32_t apps_std_sinks;

static int apps_std_is_sink(uint32_t fd)
{
	return fd >= APPS_STD_SINK_FD_BASE && fd < APPS_STD_SINK_FD_BASE + APPS_STD_SINK_FDS;
}

static const int apps_std_whence_table[] = {''', 1)

# fclose
s = s.replace('''	const uint32_t *first_in = inbufs[0].p;
	int ret;

	ret = hexagonfs_close(ctx->fds, *first_in);''', '''	const uint32_t *first_in = inbufs[0].p;
	int ret;

	if (apps_std_is_sink(*first_in)) {
		apps_std_sinks &= ~(1u << (*first_in - APPS_STD_SINK_FD_BASE));
		return 0;
	}

	ret = hexagonfs_close(ctx->fds, *first_in);''', 1)

# fread on a sink: empty file
s = s.replace('''	ssize_t ret;

	ret = hexagonfs_read(ctx->fds, first_in->fd,''', '''	ssize_t ret;

	if (apps_std_is_sink(first_in->fd)) {
		first_out->written = 0;
		first_out->is_eof = 1;
		return 0;
	}

	ret = hexagonfs_read(ctx->fds, first_in->fd,''', 1)

# fseek on a sink: nothing to move
s = s.replace('''	whence = apps_std_whence_table[first_in->whence];
''', '''	if (apps_std_is_sink(first_in->fd))
		return 0;

	whence = apps_std_whence_table[first_in->whence];
''', 1)

# open for writing -> sink
s = s.replace('''	if (rw_mode == 'w' || rw_mode == 'a') {
		fprintf(stderr, "Tried to open %s for writing\\n",
				(const char *) inbufs[3].p);
		return AEE_EUNSUPPORTED;
	}''', '''	if (rw_mode == 'w' || rw_mode == 'a') {
		for (int i = 0; i < APPS_STD_SINK_FDS; i++) {
			if (apps_std_sinks & (1u << i))
				continue;
			apps_std_sinks |= 1u << i;
			*out = APPS_STD_SINK_FD_BASE + i;
			fprintf(stderr, "Dropping writes to %s\\n",
					(const char *) inbufs[3].p);
			return 0;
		}
		return AEE_EUNSUPPORTED;
	}''', 1)

# fwrite itself, before fseek
s = s.replace('static uint32_t apps_std_fseek(void *data,', '''static uint32_t apps_std_fwrite(void *data,
				const struct fastrpc_io_buffer *inbufs,
				struct fastrpc_io_buffer *outbufs)
{
	const struct {
		uint32_t fd;
		uint32_t buf_size;
	} *first_in = inbufs[0].p;
	struct {
		uint32_t written;
		uint32_t is_eof;
	} *first_out = outbufs[0].p;

	if (!apps_std_is_sink(first_in->fd))
		return AEE_EUNSUPPORTED;

	first_out->written = first_in->buf_size;
	first_out->is_eof = 0;

	return 0;
}

static uint32_t apps_std_fseek(void *data,''', 1)

# procs[5]: the first empty slot after fread
s = re.sub(r'(\.impl = apps_std_fread,\n\t\},\n)\t\{ \.def = NULL, \.impl = NULL, \},\n',
           r'\1\t{\n\t\t.def = &apps_std_fwrite_def,\n\t\t.impl = apps_std_fwrite,\n\t},\n', s, count=1)

# frename (33): the renamed file was a dropped write, so there is nothing to move
s = s.replace('static uint32_t apps_std_fseek(void *data,', '''static uint32_t apps_std_frename(void *data,
				 const struct fastrpc_io_buffer *inbufs,
				 struct fastrpc_io_buffer *outbufs)
{
	fprintf(stderr, "Ignoring rename %s -> %s\\n",
			(const char *) inbufs[1].p, (const char *) inbufs[2].p);
	return 0;
}

static uint32_t apps_std_fseek(void *data,''', 1)
s = re.sub(r'(\.impl = apps_std_stat,\n\t\},\n)',
           r'\1\t{ .def = NULL, .impl = NULL, },\n\t{\n\t\t.def = &apps_std_frename_def,\n\t\t.impl = apps_std_frename,\n\t},\n',
           s, count=1)

s = s.replace('\t.n_procs = 32,', '\t.n_procs = sizeof(apps_std_procs) / sizeof(*apps_std_procs),', 1)

for marker in ('apps_std_is_sink(*first_in)', 'Dropping writes', 'apps_std_fwrite_def', 'is_eof = 1',
               'apps_std_frename_def', 'sizeof(apps_std_procs)'):
    assert marker in s, f'patch failed at: {marker}'
open(c, 'w').write(s)
print(f'patched {c} (+{len(s) - n} bytes)')

d = f'{src}/hexagonrpcd/interfaces/apps_std.def'
s = open(d).read()
s = s.replace('HEXAGONRPC_DEFINE_REMOTE_METHOD(31, apps_std_stat, 1, 1, 24, 0)\n',
              'HEXAGONRPC_DEFINE_REMOTE_METHOD(31, apps_std_stat, 1, 1, 24, 0)\n'
              'HEXAGONRPC_DEFINE_REMOTE_METHOD(33, apps_std_frename, 1, 2, 0, 0)\n', 1)
assert 'apps_std_frename' in s
open(d, 'w').write(s)

# methods >= 31 arrive as method 31 with the real number in the first input word
# (Qualcomm's apps_std_skel.c); stat is 31 itself, frename 33
f = f'{src}/hexagonrpcd/listener.c'
s = open(f).read()
s = s.replace('''	if (method >= ifaces[handle]->n_procs) {''', '''	if (method == 31 && REMOTE_SCALARS_INBUFS(sc) >= 1 && decoded[0].s >= 4)
		method = *(const uint32_t *) decoded[0].p;

	if (method >= ifaces[handle]->n_procs) {''', 1)
assert 'decoded[0].s >= 4' in s
# input buffers came in a fixed 256-byte array: the registry writes are bigger; take up to 64 KiB
s = s.replace('\tchar inbufs[256];', '\tstatic char inbufs[65536];', 1)
s = s.replace('&inbufs_len, 256, inbufs);', '&inbufs_len, sizeof(inbufs), inbufs);', 1)
s = s.replace('\tif (inbufs_len > 256) {\n\t\tfprintf(stderr, "Large (>256B) input buffers aren\'t implemented\\n");',
              '\tif (inbufs_len > sizeof(inbufs)) {\n\t\tfprintf(stderr, "Input buffers over %zu bytes aren\'t implemented\\n", sizeof(inbufs));', 1)
assert 'static char inbufs[65536]' in s and 'sizeof(inbufs), inbufs' in s and 'inbufs_len > sizeof' in s
open(f, 'w').write(s)

# the 3a's SSC also reads persist/sensors/registry/{sns_reg_version,parsed_file_list.csv}
f = f'{src}/hexagonrpcd/rpcd_builder.c'
s = open(f).read()
s = s.replace('\tpersist_dir = hfs_mkdir("persist", 1,', '''	char *sns_reg_version = malloc(n_prefix + sizeof("/sensors/sns_reg_version"));
	char *sns_parsed = malloc(n_prefix + sizeof("/sensors/parsed_file_list.csv"));

	if (sns_reg_version != NULL) {
		strcpy(sns_reg_version, prefix);
		strcat(sns_reg_version, "/sensors/sns_reg_version");
	}

	if (sns_parsed != NULL) {
		strcpy(sns_parsed, prefix);
		strcat(sns_parsed, "/sensors/parsed_file_list.csv");
	}

	persist_dir = hfs_mkdir("persist", 1,''', 1)
s, k = re.subn(r'hfs_mkdir\("registry", 1,(\s*)hfs_map\("registry", sns_reg\)',
               r'hfs_mkdir("registry", 3,\1hfs_map("registry", sns_reg),'
               r'\1hfs_map("sns_reg_version", sns_reg_version),'
               r'\1hfs_map("parsed_file_list.csv", sns_parsed)', s, count=1)
assert k == 1 and 'sns_parsed = malloc' in s, 'rpcd_builder patch failed'
open(f, 'w').write(s)
print('patched listener.c, rpcd_builder.c, apps_std.def')
