
while True:
    val = int("0x"+input("0x"), 16)
    print("PC 0 = " + hex((val&((1<<30)-1))<<2))
    print("PC 1 = " + hex((val>>30)<<2))
    print()
