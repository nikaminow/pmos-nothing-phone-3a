/* ABL -> mainline Linux: our DTB instead of ABL's (initrd and memory taken over in shimc.c). */
	.text
	.globl _head
_head:
	b	_start
	.long	0
	.quad	0
	.quad	0x4000000		/* image_size: room for the stack below */
	.quad	0xa
	.quad	0, 0, 0
	.ascii	"ARM\x64"
	.long	0
dtb_off:	.quad	0		/* patched by make-boot.ps1 */
k_off:		.quad	0
k_size:		.quad	0
rd_size:	.quad	0		/* size of our ramdisk in the boot image */
rd_magic:	.quad	0		/* its first 8 bytes, to find it after ABL's concatenation */
rd_off:		.quad	0		/* embedded ramdisk offset (0: use ABL's ramdisk) */
_start:
	msr	daifset, #0xf
	adr	x20, _head
	mov	x1, #0x3ff0000
	add	x1, x20, x1
	mov	sp, x1
	/* x0 = ABL's DTB already */
	ldr	x1, dtb_off
	add	x21, x20, x1
	mov	x1, x21
	ldr	x2, k_off
	add	x2, x20, x2
	ldr	x3, k_size
	ldr	x4, rd_size
	ldr	x5, rd_magic
	ldr	x6, rd_off
	cbz	x6, 1f
	add	x6, x20, x6
1:	bl	shim_c
	mov	x4, x0
	dsb	sy
	ic	iallu
	isb
	mov	x0, x21
	mov	x1, xzr
	mov	x2, xzr
	mov	x3, xzr
	br	x4
