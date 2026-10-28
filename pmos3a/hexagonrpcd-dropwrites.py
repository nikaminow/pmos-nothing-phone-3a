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

for marker in ('apps_std_is_sink(*first_in)', 'Dropping writes', 'apps_std_fwrite_def', 'is_eof = 1'):
    assert marker in s, f'patch failed at: {marker}'
open(c, 'w').write(s)
print(f'patched {c} (+{len(s) - n} bytes)')
