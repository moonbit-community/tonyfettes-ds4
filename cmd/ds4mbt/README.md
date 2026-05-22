# ds4mbt

A CLI tool that runs a MoonBit coding micro agent through the DS4 MoonBit binding. The agent can read, write, edit, and execute bash commands in a workspace directory.

## Usage

```
ds4mbt --model <GGUF_PATH> --prompt "Coding task description" [options]
```

### Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--model` | `-m` | GGUF model path (required) | |
| `--prompt` | `-p` | Coding task for the agent | |
| `--cwd` | | Workspace directory for relative tools | current directory |
| `--ctx` | `-c` | Session context size | `32768` |
| `--tokens` | `-n` | Maximum generated tokens per agent turn | `4096` |
| `--max-turns` | | Maximum tool/assistant turns | `16` |
| `--temp` | | Sampling temperature | `0.2` |
| `--top-p` | | Nucleus sampling probability | `0.95` |
| `--seed` | | Sampling seed (omit for time-based) | |
| `--backend` | | Backend: `metal`, `cuda`, or `cpu` | |
| `--metal` | | Use Metal backend | |
| `--cuda` | | Use CUDA backend | |
| `--cpu` | | Use CPU backend | |
| `--think` | | Use normal thinking mode | |
| `--think-max` | | Use Think Max when context is large enough | |
| `--nothink` | | Disable thinking mode | |

### Examples

```bash
# Run a coding task
ds4mbt --model /path/to/model.gguf --prompt "Add a README.md to cmd/ds4"

# With custom workspace
ds4mbt --model model.gguf --prompt "Refactor the main.mbt" \
  --cwd /path/to/project --temp 0.3 --max-turns 10
```

## Building

```bash
moon build cmd/ds4mbt --target native
```

## Running

```bash
moon run cmd/ds4mbt --target native -- <args>
```