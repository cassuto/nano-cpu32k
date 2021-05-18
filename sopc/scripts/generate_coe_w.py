# Generate bootrom.coe
DW_BYTES = 8


import sys

if sys.version_info < (3, 0):
    print("Please run this script under Python 3.0 or greater version.");
    exit(1)

if len(sys.argv) < 2:
    print('%s <src> <dst>' % sys.argv[0])
    exit(1);

with open(sys.argv[2], 'w') as fp, open(sys.argv[1], 'rb') as fs:
    fp.write('memory_initialization_radix = 16;\n');
    fp.write('memory_initialization_vector =\n');
    bytes = bytearray(fs.read())
    
    # Padding tail to make file size aligned at `DW_BYTES` boundary
    while True:
        if (len(bytes) & 0x7 == 0): break
        bytes.append(0);

    for i in range(0, len(bytes),DW_BYTES):
        for off in range(DW_BYTES-1,-1,-1):
            fp.write('%02x' % (bytes[i+off]) )
        fp.write(';\n' if i+DW_BYTES>=len(bytes) else ',')
