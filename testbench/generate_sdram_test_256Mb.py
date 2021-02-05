# Coded for python 2.7, not 3.X

import sys

if len(sys.argv) < 1:
    print('%s <dst>_bi.memh' % sys.argv[0])
    exit(1);

fp = [open('%s_b%d.mem' % (sys.argv[1], i), 'w') for i in xrange(4)]
bytes = [chr(x%128) for x in xrange(8192)]
for addr in xrange(0, len(bytes), 2):
    col = (addr >> 2) & 0x1ff; # 9bit
    ba = (addr >>10) & 0x3; # 2bit
    row = (addr >>12) & 0x1fff; # 13bit

    bl = bytes[addr];
    bh = bytes[addr+1];
    fp[ba].write('%02x%02x\n' % (ord(bh),ord(bl)))
