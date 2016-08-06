Fixed Width Interchange
===
Fixed Width Interchange, FWI, is a language similar to Google's Protobuf, but designed for applications 
where the buffer is a fixed, compile-time set width, and can be used in-place without building messages.

A few use-cases include:
- Shared Memory
- Websockets
- Network Data Transfer

FWI files can be compiled down to the language of your choice, such as C++ or JavaScript.

FWI data sets use exactly how much memory they need, i.e. all indexes and mapping is done at compile-time 
and is not packaged with the payload. If your block contains 4 bytes worth of data, the entire payload size will
be 4 bytes. 

Note that booleans are stored in as little space as possible, and are encoded as a single bit in a byte, rather
than taking up the whole byte. 8 boolean values will take up only 1 byte.

## Installation
Install the FWI compiler with 
```
gem install fwi
```

To compile a .fwi file, use the `fwi` command. Use `fwi -h` for usage instructions.

To include the generated sources in your language of choice, you must also grab the FWI Standard Library,
available under `stdlib/` on this project. We have made every effort to make the standard library as small as 
possible for each language.

## Example
```
namespace MyNamespace

enum MyEnum {
    VAL_1,
    VAL_2
}

namespace MySubNS {
    block MyBlock {
        bool bool_array[8]
    }
}

block MyBlock {
    bool bool_1, bool_2

    u16 my_unsigned_16
    i32 my_signed_32
    int my_other_signed_32
    long my_signed_64

    float my_float
    double my_double

    MyEnum my_enum_array[12]
    MySubNS::MyBlock my_sub_block
}
```