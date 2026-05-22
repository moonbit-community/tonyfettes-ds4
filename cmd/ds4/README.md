# ds4

A CLI tool that runs DeepSeek V4 Flash through the DS4 MoonBit binding.

## Usage

```
ds4 --model <GGUF_PATH> --prompt "Your prompt here" [options]
```

### Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--model` | `-m` | GGUF model path (required) | |
| `--prompt` | `-p` | Prompt to run | |
| `--ctx` | `-c` | Session context size | `32768` |
| `--tokens` | `-n` | Maximum generated tokens | `50000` |
| `--temp` | | Sampling temperature (0 = greedy) | `1.0` |
| `--top-p` | | Nucleus sampling probability | `1.0` |
| `--seed` | | Sampling seed (omit for time-based) | |
| `--system` | | System prompt | `"You are a helpful assistant"` |
| `--backend` | | Backend: `metal`, `cuda`, or `cpu` | |
| `--metal` | | Use Metal backend | |
| `--cuda` | | Use CUDA backend | |
| `--cpu` | | Use CPU backend | |
| `--think` | | Use normal thinking mode | |
| `--think-max` | | Use Think Max when context is large enough | |
| `--nothink` | | Disable thinking mode | |
| `--inspect` | | Load model and print DS4 summary only | |

### Examples

```bash
# Basic prompt
ds4 --model /path/to/model.gguf --prompt "Hello, world!"

# With custom settings
ds4 --model model.gguf --prompt "Explain quantum computing" \
  --temp 0.8 --top-p 0.95 --ctx 65536 --tokens 2000

# Inspect model
ds4 --model model.gguf --inspect
```

## Building

```bash
moon build cmd/ds4 --target native
```

## Running

```bash
moon run cmd/ds4 --target native -- <args>
```