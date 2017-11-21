# Functions

**Sample input file**
```
Type:
int32
bool
binaryop = (int32, int32) -> int32

Symbol:
add(int32, int32) -> int32
subtract(int32, int32) -> int32
randomop() -> binaryop

Function:
f1: (int32, int32, int32) -> int32
f2: (binaryop) -> int32
f3: (int32, int32, int32, int32) -> int32
f4: () -> int32
f5: (int32, int32) -> binaryop
```

**Usage (Swift)**
```Swift
let encoding = f1Encode { o1, o2, o3 in
    subtract(
        add(o1, 2 as Int32),
        add(o2, o3)
    )
}
```
```Swift
class Implementation: Symbols {
    func add(_ o1: Int32, _ o2: Int32) -> Int32 {
        return o1 + o2
    }
    func subtract(_ o1: Int32, _ o2: Int32) -> Int32 {
        return o1 - o2
    }
    func randomop() -> binaryop {
        return { o1, o2 in o1 * o2 }
    }
}

let function = try! f1Decode(function: encoding, symbols: Implementation())
assert(function(1, 2, 3) == -2)
```

## Getting Started

1. Write specification file (See sample input)
1. Compile specification to protobuf file and source code file 1
1. Compile protobuf file to source code file 2
1. Add both source code file 1 and 2 to your project
