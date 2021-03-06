
import sys

if sys.version_info < (3, 0):
    print("Please run this script under Python 3.0 or greater version.");
    exit(1)

if len(sys.argv) < 2:
    print('%s <src> <dst>_bi.memh' % sys.argv[0])
    exit(1);

# Coded for python 2.7, not 3.X
with open(sys.argv[1], 'rb') as fs:
    fp = [open('%s_b%d.mem' % (sys.argv[2], i), 'w') for i in range(4)]
    bytes = fs.read()
    for addr in range(0, len(bytes), 2):
        col = (addr >> 2) & 0x1ff; # 9bit
        ba = (addr >>10) & 0x3; # 2bit
        row = (addr >>12) & 0x1fff; # 13bit

        bl = bytes[addr];
        bh = bytes[addr+1];
        fp[ba].write('%02x%02x\n' % (bh,bl))
