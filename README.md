# ds4.mbt

MoonBit native bindings for DwarfStar 4.

DS4 source files are vendored directly in this package.

The MoonBit package builds the DS4 sources directly as native stubs:
`ds4_stub.c`, `ds4.c`, and `ds4_metal.m` on macOS.

Validate the package:

```sh
moon test --target native
```

Run the DS4 command:

```sh
moon build cmd/ds4 --target native
_build/native/debug/build/cmd/ds4/ds4.exe -p "Write a short haiku about MoonBit"
```

The command defaults to the downloaded model at
`~/Workspace/ds4/gguf/DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix.gguf`.
Use `-m /path/to/model.gguf` to override it.

Like the upstream `./ds4` CLI, `cmd/ds4` samples by default with `--temp 1`,
`--top-p 1`, and a time-based seed. For deterministic comparisons, pass the
same seed to both commands:

```sh
_build/native/debug/build/cmd/ds4/ds4.exe --seed 42 -p "Write a short haiku about MoonBit"
```
