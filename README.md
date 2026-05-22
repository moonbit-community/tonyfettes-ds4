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
_build/native/debug/build/cmd/ds4/ds4.exe -m /path/to/model.gguf -p "Write a short haiku about MoonBit"
```

Pass the GGUF model explicitly with `-m /path/to/model.gguf`; the CLI does not
use a built-in default model path.

Like the upstream `./ds4` CLI, `cmd/ds4` samples by default with `--temp 1`,
`--top-p 1`, and a time-based seed. For deterministic comparisons, pass the
same seed to both commands:

```sh
_build/native/debug/build/cmd/ds4/ds4.exe -m /path/to/model.gguf --seed 42 -p "Write a short haiku about MoonBit"
```

Run the MoonBit coding micro agent:

```sh
moon build cmd/ds4mbt --target native
_build/native/debug/build/cmd/ds4mbt/ds4mbt.exe -m /path/to/model.gguf -p "Add focused tests for the parser"
```

`cmd/ds4mbt` embeds the MoonBit agent guide from
`~/Documents/moonbit-agent-guide/moonbit-agent-guide` in its system prompt and
executes four tool blocks emitted by the model: `read`, `write`, `edit`, and
`bash`. Use `--cwd /path/to/workspace` to point the tools at a different
MoonBit codebase.
