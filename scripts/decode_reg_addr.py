
while True:
    val = int("0x"+input("0x"), 16)
    print("R 0 = " + hex(val&((1<<5)-1)))
    print("R 1 = " + hex(val>>5))
    print()
