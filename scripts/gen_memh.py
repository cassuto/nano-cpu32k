
import sys

if sys.version_info < (3, 0):
    print("python3 is required.");
    exit(1)

if len(sys.argv) < 2:
    print('%s <src> <dst>' % sys.argv[0])
    exit(1);

DW_BYTES = 4
    
with open(sys.argv[2], 'w') as fp, open(sys.argv[1], 'rb') as fs:
    bytes = fs.read()
    while True:
        if (len(bytes) & (DW_BYTES-1) == 0): break
        bytes += chr(0);

    for i in range(0, len(bytes),DW_BYTES):
        # Little-endian
        for off in range(DW_BYTES-1,-1,-1):
            fp.write('%02x' % (bytes[i+off]) )
        fp.write('\n')
