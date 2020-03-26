
import sys

if len(sys.argv) < 2:
    print('%s <src> <dst>' % sys.argv[0])
    exit(1);

# Coded for python 2.7, not 3.X
with open(sys.argv[2], 'w') as fp, open(sys.argv[1], 'rb') as fs:
    fp.write('memory_initialization_radix = 16;\n');
    fp.write('memory_initialization_vector =\n');
    bytes = fs.read()
    while True:
        if (len(bytes) & 0x3 == 0): break
        bytes += chr(0);

    for i in xrange(0, len(bytes),4):
        for off in xrange(3,-1,-1):
            fp.write('%02x' % (ord(bytes[i+off])) )
        fp.write(';\n' if i+4>=len(bytes) else ',')
