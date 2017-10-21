# Functions

**Sample input file**
```
Type:
int32
bool
binaryop = (int32, int32) -> int32
f = () -> int32

Symbol:
add(int32, int32) -> int32
minus(int32, int32) -> int32
randomop() -> binaryop
#myif(bool, f, f) -> int32

Function:
f1: (int32, int32, int32) -> int32
#f2: (binaryop) -> int32
f3: (int32, int32, int32, int32) -> int32
f4: () -> int32
f5: (int32, int32) -> binaryop
```

**Usage (Swift)**
```
class Implementation: Symbols {
    func add(_ o1: Int32, _ o2: Int32) -> Int32 {
        return o1 + o2
    }
    func minus(_ o1: Int32, _ o2: Int32) -> Int32 {
        return o1 - o2
    }
    func randomop() -> binaryop {
        return { o1, o2 in o1 * o2 }
    }
}

// protobuf message
let encoding = f1Encode { o1, o2, o3 in minus(add(o1, 2 as Int32), add(o2, o3)) }

let function = f1Decode(function: encoding, symbols: Implementation())

assert(function(1, 2, 3) == -2)
```
