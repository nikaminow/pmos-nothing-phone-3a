"""Drive GPIO lines and hold them until killed (GPIO chardev v1 ioctl):
gpio-hold.py [chip] 44=1 [45=0 ...]; chip: a path substring of the controller, default the TLMM
(f100000.pinctrl), e.g. pmic@5:gpio for PMR735B (line = PMIC gpio number - 1)."""
import fcntl, glob, os, signal, struct, sys

args = sys.argv[1:]
match = args.pop(0) if '=' not in args[0] else 'f100000.pinctrl'
chip = next(c for c in sorted(glob.glob('/dev/gpiochip*'))
            if match in os.path.realpath(f'/sys/bus/gpio/devices/{os.path.basename(c)}'))
pins = [tuple(map(int, a.split('='))) for a in args]
req = struct.pack('64I', *([p for p, _ in pins] + [0] * (64 - len(pins))))
req += struct.pack('I', 1 << 1)                                          # GPIOHANDLE_REQUEST_OUTPUT
req += bytes([v for _, v in pins] + [0] * (64 - len(pins)))
req += b'gpio-hold'.ljust(32, b'\0') + struct.pack('Ii', len(pins), 0)
fd = os.open(chip, os.O_RDWR)
fcntl.ioctl(fd, 0xC16CB403, bytearray(req))                              # GPIO_GET_LINEHANDLE_IOCTL
print(f'{chip}: holding {pins}', flush=True)
signal.pause()
