# ds4.mbt

MoonBit native bindings for DwarfStar 4.

DS4 source files are vendored directly in this package.

The MoonBit package builds the DS4 sources directly as native stubs:
`ds4_stub.c`, `ds4.c`, and `ds4_metal.m` on macOS.

Validate the package:

```sh
moon test --target native
```
