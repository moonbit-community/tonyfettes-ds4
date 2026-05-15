///|
struct Config {
  model_path : String
  prompt : String
  system : String
  ctx_size : Int
  n_predict : Int
  temperature : Float
  top_p : Float
  seed : UInt64
  backend : @ds4lib.Backend
  think_mode : @ds4lib.ThinkMode
  inspect : Bool
}

///|
const ANSI_THINK : String = "\u001b[90m"

///|
const ANSI_RESET : String = "\u001b[0m"

///|
enum ThinkMarker {
  Open
  Close
}

///|
struct ThinkRenderer {
  format_thinking : Bool
  use_color : Bool
  mut in_think : Bool
  mut color_open : Bool
  mut last_output_newline : Bool
  mut pending : String
}

///|
fn ThinkRenderer::new(format_thinking : Bool) -> ThinkRenderer {
  {
    format_thinking,
    use_color: true,
    in_think: format_thinking,
    color_open: false,
    last_output_newline: true,
    pending: "",
  }
}

///|
fn next_think_marker(text : StringView) -> (Int, ThinkMarker)? {
  let open = text.find("<think>")
  let close = text.find("</think>")
  match (open, close) {
    (None, None) => None
    (Some(i), None) => Some((i, Open))
    (None, Some(i)) => Some((i, Close))
    (Some(open_i), Some(close_i)) =>
      if open_i < close_i {
        Some((open_i, Open))
      } else {
        Some((close_i, Close))
      }
  }
}

///|
fn ThinkRenderer::write_text(
  self : ThinkRenderer,
  out : StringBuilder,
  text : StringView,
) -> Unit {
  if text.length() == 0 {
    return
  }
  if self.in_think && self.use_color && !self.color_open {
    out.write_string(ANSI_THINK)
    self.color_open = true
  }
  out.write_stringview(text)
  self.last_output_newline = text.rev_find("\n") is Some(i) &&
    i == text.length() - 1
}

///|
fn ThinkRenderer::close_think(
  self : ThinkRenderer,
  out : StringBuilder,
) -> Unit {
  self.in_think = false
  if self.color_open {
    out.write_string(ANSI_RESET)
    self.color_open = false
  }
  if !self.last_output_newline {
    out.write_string("\n")
    self.last_output_newline = true
  }
}

///|
fn ThinkRenderer::render_complete(
  self : ThinkRenderer,
  text : StringView,
) -> String {
  let out = StringBuilder(size_hint=text.length() + 16)
  let mut rest = text
  while rest.length() > 0 {
    match next_think_marker(rest) {
      None => {
        self.write_text(out, rest)
        rest = rest.view(start_offset=rest.length())
      }
      Some((index, Open)) => {
        self.write_text(out, rest.view(end_offset=index))
        self.in_think = true
        rest = rest.view(start_offset=index + "<think>".length())
      }
      Some((index, Close)) => {
        self.write_text(out, rest.view(end_offset=index))
        self.close_think(out)
        rest = rest.view(start_offset=index + "</think>".length())
      }
    }
  }
  out.to_string()
}

///|
fn ThinkRenderer::render_piece(self : ThinkRenderer, raw : String) -> String {
  if !self.format_thinking {
    return raw
  }
  let input = self.pending + raw
  match input.rev_find("<") {
    Some(index) if input.length() - index < "</think>".length() => {
      self.pending = input.view(start_offset=index).to_owned()
      self.render_complete(input.view(end_offset=index))
    }
    _ => {
      self.pending = ""
      self.render_complete(input[:])
    }
  }
}

///|
fn ThinkRenderer::finish(self : ThinkRenderer) -> String {
  if !self.format_thinking {
    return ""
  }
  let out = StringBuilder(size_hint=self.pending.length() + 8)
  out.write_string(self.render_complete(self.pending[:]))
  self.pending = ""
  if self.color_open {
    out.write_string(ANSI_RESET)
    self.color_open = false
  }
  out.to_string()
}

///|
fn default_model_path() -> String {
  let home = @env.get_env_var("HOME").unwrap_or("/Users/dii")
  home +
  "/Workspace/ds4/gguf/DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix.gguf"
}

///|
fn default_config() -> Config {
  {
    model_path: default_model_path(),
    prompt: "",
    system: "You are a helpful assistant",
    ctx_size: 32768,
    n_predict: 50000,
    temperature: 1.0,
    top_p: 1.0,
    seed: 0,
    backend: @ds4lib.Backend::default(),
    think_mode: @ds4lib.ThinkMode::high(),
    inspect: false,
  }
}

///|
fn usage() -> Unit {
  let text =
    #|Usage: ds4 [options] -p PROMPT
    #|
    #|Build:
    #|  moon build cmd/ds4 --target native
    #|  _build/native/debug/build/cmd/ds4/ds4.exe -p PROMPT
    #|
    #|Options:
    #|  -p, --prompt TEXT    Prompt to run.
    #|  -m, --model FILE     GGUF model path.
    #|  -c, --ctx N          Session context size. Default: 32768
    #|  -n, --tokens N       Maximum generated tokens. Default: 50000
    #|  --temp F             Sampling temperature. 0 is greedy. Default: 1
    #|  --top-p F            Nucleus sampling probability. Default: 1
    #|  --seed N             Sampling seed. Default: time-based
    #|  --system TEXT        System prompt. Default: You are a helpful assistant
    #|  --backend NAME       Select backend: metal, cuda, or cpu.
    #|  --metal              Use Metal backend.
    #|  --cuda               Use CUDA backend.
    #|  --cpu                Use CPU backend.
    #|  --think              Use normal thinking mode. Default.
    #|  --think-max          Use Think Max when context is large enough.
    #|  --nothink            Disable thinking mode.
    #|  --inspect            Load the model and print its DS4 summary only.
    #|  -h, --help           Show this help.
    #|
    #|Default model:
    #|  ~/Workspace/ds4/gguf/DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix.gguf
    #|
  println(text)
}

///|
fn parse_positive_int(value : String, opt : String) -> Int {
  let parsed = @string.parse_int(value) catch {
    _ => abort("ds4: invalid value for " + opt + ": " + value)
  }
  if parsed <= 0 {
    abort("ds4: invalid value for " + opt + ": " + value)
  }
  parsed
}

///|
fn parse_uint64(value : String, opt : String) -> UInt64 {
  let parsed = @string.parse_uint64(value) catch {
    _ => abort("ds4: invalid value for " + opt + ": " + value)
  }
  if parsed == 0 {
    abort("ds4: invalid value for " + opt + ": " + value)
  }
  parsed
}

///|
fn parse_float_range(
  value : String,
  opt : String,
  min : Float,
  max : Float,
) -> Float {
  let parsed = Float::from_double(@string.parse_double(value)) catch {
    _ => abort("ds4: invalid value for " + opt + ": " + value)
  }
  if parsed < min || parsed > max {
    abort("ds4: invalid value for " + opt + ": " + value)
  }
  parsed
}

///|
fn parse_backend(value : String) -> @ds4lib.Backend {
  if value == "metal" {
    @ds4lib.Backend::metal()
  } else if value == "cuda" {
    @ds4lib.Backend::cuda()
  } else if value == "cpu" {
    @ds4lib.Backend::cpu()
  } else {
    abort("ds4: invalid backend: " + value)
  }
}

///|
fn need_arg(args : Array[String], index : Int, opt : String) -> String {
  if index + 1 >= args.length() {
    abort("ds4: " + opt + " needs an argument")
  }
  args[index + 1]
}

///|
fn parse_args(args : Array[String]) -> Config? {
  let mut config = default_config()
  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    if arg == "-h" || arg == "--help" {
      return None
    } else if arg == "-p" || arg == "--prompt" {
      config = { ..config, prompt: need_arg(args, i, arg) }
      i = i + 1
    } else if arg == "-m" || arg == "--model" {
      config = { ..config, model_path: need_arg(args, i, arg) }
      i = i + 1
    } else if arg == "-c" || arg == "--ctx" {
      let value = need_arg(args, i, arg)
      config = { ..config, ctx_size: parse_positive_int(value, arg) }
      i = i + 1
    } else if arg == "-n" || arg == "--tokens" {
      let value = need_arg(args, i, arg)
      config = { ..config, n_predict: parse_positive_int(value, arg) }
      i = i + 1
    } else if arg == "--temp" {
      let value = need_arg(args, i, arg)
      config = {
        ..config,
        temperature: parse_float_range(value, arg, 0.0, 100.0),
      }
      i = i + 1
    } else if arg == "--top-p" {
      let value = need_arg(args, i, arg)
      config = { ..config, top_p: parse_float_range(value, arg, 0.0, 1.0) }
      i = i + 1
    } else if arg == "--seed" {
      let value = need_arg(args, i, arg)
      config = { ..config, seed: parse_uint64(value, arg) }
      i = i + 1
    } else if arg == "--system" {
      config = { ..config, system: need_arg(args, i, arg) }
      i = i + 1
    } else if arg == "--backend" {
      let value = need_arg(args, i, arg)
      config = { ..config, backend: parse_backend(value) }
      i = i + 1
    } else if arg == "--metal" {
      config = { ..config, backend: @ds4lib.Backend::metal() }
    } else if arg == "--cuda" {
      config = { ..config, backend: @ds4lib.Backend::cuda() }
    } else if arg == "--cpu" {
      config = { ..config, backend: @ds4lib.Backend::cpu() }
    } else if arg == "--think" {
      config = { ..config, think_mode: @ds4lib.ThinkMode::high() }
    } else if arg == "--think-max" {
      config = { ..config, think_mode: @ds4lib.ThinkMode::max() }
    } else if arg == "--nothink" {
      config = { ..config, think_mode: @ds4lib.ThinkMode::none() }
    } else if arg == "--inspect" {
      config = { ..config, inspect: true }
    } else {
      abort("ds4: unknown option: " + arg)
    }
    i = i + 1
  }
  Some(config)
}

///|
async fn generate(config : Config) -> Unit raise @ds4lib.Ds4Error {
  let engine = @ds4lib.Engine::open(
    @ds4lib.EngineConfig::new(config.model_path, backend=config.backend),
  )
  if config.inspect {
    engine.summary()
    return
  }
  if config.prompt == "" {
    usage()
    abort("ds4: missing prompt")
  }
  let think_mode = config.think_mode.for_context(config.ctx_size)
  let prompt = engine.encode_chat_prompt(
    config.prompt,
    system=config.system,
    think_mode~,
  )
  let session = engine.create_session(config.ctx_size)
  session.sync(prompt)
  let eos = engine.token_eos()
  let mut generated = 0
  let room = session.ctx() - session.pos()
  let max_tokens = if room <= 1 {
    0
  } else if config.n_predict > room - 1 {
    room - 1
  } else {
    config.n_predict
  }
  let sampler = @ds4lib.Sampler::new(
    if config.seed == 0 {
      @env.now()
    } else {
      config.seed
    },
  )
  let stdout = @io.BufferedWriter::new(@stdio.stdout, size=4096)
  let renderer = ThinkRenderer::new(think_mode.enabled())
  while generated < max_tokens {
    let token = session.sample(
      sampler,
      temperature=config.temperature,
      top_p=config.top_p,
    )
    if token == eos || token < 0 {
      break
    }
    stdout.write(renderer.render_piece(engine.token_text(token))) catch {
      _ => abort("ds4: stdout write failed")
    }
    stdout.flush() catch {
      _ => abort("ds4: stdout flush failed")
    }
    session.eval(token)
    generated = generated + 1
  }
  let tail = renderer.finish()
  if tail != "" {
    stdout.write(tail) catch {
      _ => abort("ds4: stdout write failed")
    }
  }
  if !renderer.last_output_newline {
    stdout.write("\n") catch {
      _ => abort("ds4: stdout write failed")
    }
  }
  stdout.flush() catch {
    _ => abort("ds4: stdout flush failed")
  }
}

///|
async fn main {
  match parse_args(@env.args()) {
    None => usage()
    Some(config) =>
      generate(config) catch {
        @ds4lib.Ds4Error::OpenFailed(status) =>
          abort("ds4: failed to open model, status " + status.to_string())
        @ds4lib.Ds4Error::SessionCreateFailed(status, message) =>
          abort(
            "ds4: failed to create session, status " +
            status.to_string() +
            ": " +
            message,
          )
        @ds4lib.Ds4Error::OperationFailed(op~, status~, message~) =>
          abort(
            "ds4: " +
            op +
            " failed, status " +
            status.to_string() +
            ": " +
            message,
          )
      }
  }
}
