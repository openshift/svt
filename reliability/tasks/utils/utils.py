import random
import string

import string
import random
def random_string(length):
    return ''.join(random.choice(string.ascii_lowercase) for m in range(length))

if __name__ == "__main__":
    print(random_string(5))
    print(random_string(256))  