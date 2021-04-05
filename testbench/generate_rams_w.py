
import sys

if sys.version_info < (3, 0):
    print("Please run this script under Python 3.0 or greater version.");
    exit(1)

if len(sys.argv) < 2:
    print('%s <src> <dst>' % sys.argv[0])
    exit(1);

with open(sys.argv[2], 'w') as fp, open(sys.argv[1], 'rb') as fs:
    bytes = fs.read()
    while True:
        if (len(bytes) & 0x3 == 0): break
        bytes += chr(0);

    for i in range(0, len(bytes),4):
        for off in range(3,-1,-1):
            fp.write('%02x' % (bytes[i+off]) )
        fp.write('\n')
