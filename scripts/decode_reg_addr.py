
while True:
    val = int("0x"+input("0x"), 16)
    print("R" + str(val&((1<<5)-1)))
    print("R" + str(val>>5))
    print()
