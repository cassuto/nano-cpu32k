
import sys

if len(sys.argv) < 2:
    print('%s <src> <dst>' % sys.argv[0])
    exit(1);

# Coded for python 2.7, not 3.X
with open(sys.argv[2], 'w') as fp, open(sys.argv[1], 'rb') as fs:
    bytes = fs.read()
    for b in bytes:
        fp.write('%02x' % ord(b))
        fp.write('\n')
