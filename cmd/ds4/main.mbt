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
fn default_config() -> Config {
  {
    model_path: "",
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
priv suberror CliError {
  Message(String)
}

///|
impl Show for CliError with output(self : CliError, logger) {
  match self {
    Message(message) => logger.write_string(message)
  }
}

///|
fn parse_positive_int(value : String, opt : String) -> Int raise CliError {
  let parsed = @string.parse_int(value) catch {
    _ => raise CliError::Message("ds4: invalid value for " + opt + ": " + value)
  }
  if parsed <= 0 {
    raise CliError::Message("ds4: invalid value for " + opt + ": " + value)
  }
  parsed
}

///|
fn parse_uint64(value : String, opt : String) -> UInt64 raise CliError {
  let parsed = @string.parse_uint64(value) catch {
    _ => raise CliError::Message("ds4: invalid value for " + opt + ": " + value)
  }
  if parsed == 0 {
    raise CliError::Message("ds4: invalid value for " + opt + ": " + value)
  }
  parsed
}

///|
fn parse_float_range(
  value : String,
  opt : String,
  min : Float,
  max : Float,
) -> Float raise CliError {
  let parsed = Float::from_double(@string.parse_double(value)) catch {
    _ => raise CliError::Message("ds4: invalid value for " + opt + ": " + value)
  }
  if parsed < min || parsed > max {
    raise CliError::Message("ds4: invalid value for " + opt + ": " + value)
  }
  parsed
}

///|
fn parse_backend(value : String) -> @ds4lib.Backend raise CliError {
  if value == "metal" {
    @ds4lib.Backend::metal()
  } else if value == "cuda" {
    @ds4lib.Backend::cuda()
  } else if value == "cpu" {
    @ds4lib.Backend::cpu()
  } else {
    raise CliError::Message("ds4: invalid backend: " + value)
  }
}

///|
fn cli_command() -> @argparse.Command {
  @argparse.Command::new(
    "ds4",
    about="Run DeepSeek V4 Flash through the DS4 MoonBit binding.",
    arg_required_else_help=true,
    options=[
      @argparse.OptionArg::new(
        "prompt",
        short='p',
        long="prompt",
        about="Prompt to run.",
        allow_hyphen_values=true,
      ),
      @argparse.OptionArg::new(
        "model",
        short='m',
        long="model",
        about="GGUF model path.",
        required=true,
        allow_hyphen_values=true,
      ),
      @argparse.OptionArg::new(
        "ctx",
        short='c',
        long="ctx",
        about="Session context size.",
        default_values=["32768"],
        allow_hyphen_values=true,
      ),
      @argparse.OptionArg::new(
        "tokens",
        short='n',
        long="tokens",
        about="Maximum generated tokens.",
        default_values=["50000"],
        allow_hyphen_values=true,
      ),
      @argparse.OptionArg::new(
        "temp",
        long="temp",
        about="Sampling temperature. 0 is greedy.",
        default_values=["1"],
        allow_hyphen_values=true,
      ),
      @argparse.OptionArg::new(
        "top_p",
        long="top-p",
        about="Nucleus sampling probability.",
        default_values=["1"],
        allow_hyphen_values=true,
      ),
      @argparse.OptionArg::new(
        "seed",
        long="seed",
        about="Sampling seed. Omit for time-based.",
        allow_hyphen_values=true,
      ),
      @argparse.OptionArg::new(
        "system",
        long="system",
        about="System prompt.",
        default_values=["You are a helpful assistant"],
        allow_hyphen_values=true,
      ),
      @argparse.OptionArg::new(
        "backend",
        long="backend",
        about="Select backend: metal, cuda, or cpu.",
      ),
    ],
    flags=[
      @argparse.FlagArg::new("metal", long="metal", about="Use Metal backend."),
      @argparse.FlagArg::new("cuda", long="cuda", about="Use CUDA backend."),
      @argparse.FlagArg::new("cpu", long="cpu", about="Use CPU backend."),
      @argparse.FlagArg::new(
        "think",
        long="think",
        about="Use normal thinking mode.",
      ),
      @argparse.FlagArg::new(
        "think_max",
        long="think-max",
        about="Use Think Max when context is large enough.",
      ),
      @argparse.FlagArg::new(
        "nothink",
        long="nothink",
        about="Disable thinking mode.",
      ),
      @argparse.FlagArg::new(
        "inspect",
        long="inspect",
        about="Load the model and print its DS4 summary only.",
      ),
    ],
    groups=[
      @argparse.ArgGroup::new("input", required=true, multiple=true, args=[
        "prompt", "inspect",
      ]),
      @argparse.ArgGroup::new("backend", multiple=false, args=[
        "backend", "metal", "cuda", "cpu",
      ]),
      @argparse.ArgGroup::new("thinking", multiple=false, args=[
        "think", "think_max", "nothink",
      ]),
    ],
  )
}

///|
fn option_value(matches : @argparse.Matches, name : String) -> String? {
  match matches.values.get(name) {
    Some(values) => values.get(0)
    None => None
  }
}

///|
fn flag_set(matches : @argparse.Matches, name : String) -> Bool {
  match matches.flags.get(name) {
    Some(value) => value
    None => false
  }
}

///|
fn config_from_matches(matches : @argparse.Matches) -> Config raise CliError {
  let mut config = default_config()
  if option_value(matches, "prompt") is Some(value) {
    config = { ..config, prompt: value }
  }
  if option_value(matches, "model") is Some(value) {
    config = { ..config, model_path: value }
  }
  if option_value(matches, "ctx") is Some(value) {
    config = { ..config, ctx_size: parse_positive_int(value, "--ctx") }
  }
  if option_value(matches, "tokens") is Some(value) {
    config = { ..config, n_predict: parse_positive_int(value, "--tokens") }
  }
  if option_value(matches, "temp") is Some(value) {
    config = {
      ..config,
      temperature: parse_float_range(value, "--temp", 0.0, 100.0),
    }
  }
  if option_value(matches, "top_p") is Some(value) {
    config = { ..config, top_p: parse_float_range(value, "--top-p", 0.0, 1.0) }
  }
  if option_value(matches, "seed") is Some(value) {
    config = { ..config, seed: parse_uint64(value, "--seed") }
  }
  if option_value(matches, "system") is Some(value) {
    config = { ..config, system: value }
  }
  if option_value(matches, "backend") is Some(value) {
    config = { ..config, backend: parse_backend(value) }
  }
  if flag_set(matches, "metal") {
    config = { ..config, backend: @ds4lib.Backend::metal() }
  }
  if flag_set(matches, "cuda") {
    config = { ..config, backend: @ds4lib.Backend::cuda() }
  }
  if flag_set(matches, "cpu") {
    config = { ..config, backend: @ds4lib.Backend::cpu() }
  }
  if flag_set(matches, "think") {
    config = { ..config, think_mode: @ds4lib.ThinkMode::high() }
  }
  if flag_set(matches, "think_max") {
    config = { ..config, think_mode: @ds4lib.ThinkMode::max() }
  }
  if flag_set(matches, "nothink") {
    config = { ..config, think_mode: @ds4lib.ThinkMode::none() }
  }
  if flag_set(matches, "inspect") {
    config = { ..config, inspect: true }
  }
  config
}

///|
fn parse_args(args : Array[String]) -> Config raise Error {
  let argv = if args.length() > 0 { args[1:] } else { args[:] }
  let matches = cli_command().parse(argv~, env=@env.get_env_vars())
  config_from_matches(matches)
}

///|
async fn generate(config : Config) -> Unit raise Error {
  let engine = @ds4lib.Engine::open(
    @ds4lib.EngineConfig::new(
      config.model_path,
      backend=config.backend,
      inspect_only=config.inspect,
    ),
  )
  if config.inspect {
    engine.summary()
    return
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
    stdout.write(renderer.render_piece(engine.token_text(token)))
    stdout.flush()
    session.eval(token)
    generated = generated + 1
  }
  let tail = renderer.finish()
  if tail != "" {
    stdout.write(tail)
  }
  if !renderer.last_output_newline {
    stdout.write("\n")
  }
  stdout.flush()
}

///|
async fn main raise Error {
  let config = parse_args(@env.args())
  generate(config)
}
