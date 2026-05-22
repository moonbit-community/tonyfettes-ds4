///|
struct Config {
  model_path : String
  task : String
  cwd : String
  ctx_size : Int
  n_predict : Int
  max_turns : Int
  temperature : Float
  top_p : Float
  seed : UInt64
  backend : @ds4lib.Backend
  think_mode : @ds4lib.ThinkMode
}

///|
struct ToolCall {
  name : String
  body : String
}

///|
struct ReadRequest {
  path : String
  start_line : Int
  end_line : Int
}

///|
const TOOL_BEGIN : String = "<tool:"

///|
const TOOL_END : String = "</tool>"

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
const SYSTEM_PROMPT : String =
  #|You are ds4mbt, a micro coding agent specialized in MoonBit codebases.
  #|
  #|You can use exactly four tools by emitting one or more tool blocks as your entire assistant message:
  #|
  #|<tool:read>
  #|relative/or/absolute/path
  #|</tool>
  #|
  #|<tool:read>
  #|relative/or/absolute/path
  #|---
  #|start_line
  #|---
  #|end_line
  #|</tool>
  #|
  #|<tool:write>
  #|path
  #|---
  #|complete file contents
  #|</tool>
  #|
  #|<tool:edit>
  #|path
  #|---
  #|exact old text
  #|---
  #|replacement text
  #|</tool>
  #|
  #|<tool:bash>
  #|command
  #|</tool>
  #|
  #|Use read before editing files. Read output is line-numbered; use ranged reads for large files. Prefer edit for small changes and write only when replacing or creating a full file. Use bash for builds, tests, search, and formatting. You may emit multiple independent tool blocks in one response; they will run in parallel and observations will be returned in call order. Do not emit dependent tools in the same response. After tool results, continue with more tool blocks or finish with a concise final answer. Do not invent tool names.
  #|
  #|MoonBit language guide:
  #|- Files use .mbt. Top-level declarations include fn, async fn, struct, enum, type, trait, impl, const, let, and extern.
  #|- Function syntax: fn name(arg : Type, optional? : Type = default, label~ : Type) -> Return raise Error { ... }. Methods use Type::method(self : Type, ...). Public declarations use pub fn or pub(all) struct.
  #|- Async functions are declared with async fn and call async APIs directly inside async contexts. The main entry can be async fn main raise Error { ... }.
  #|- Variables are immutable with let; mutable bindings use let mut x = value and assignment x = new_value. Mutable struct fields use mut in the field declaration.
  #|- Struct literals use { field, other: value } and updates use { ..old, field: value }. Pattern matching uses match expr { Case(args) => ..., _ => ... }.
  #|- Option values are Some(value) or None. Result-like error handling uses raise declarations and catch blocks. Use return for early return from Unit functions when useful.
  #|- Strings are UTF-16-indexed String/StringView. Use s[:] for a StringView, .find, .split_once, .trim_space, .to_owned, .replace_all, and StringBuilder for assembled text.
  #|- Arrays use [a, b], .length(), .get(index), slicing arr[start:], and .join(sep) for string arrays. Loops include while, for x in array, and for i = 0; i < n; i = i + 1.
  #|- Imports are declared in moon.pkg, commonly as "package/name" @alias. Use @alias.function and @alias.Type when calling imported packages.
  #|- Native command packages set supported_targets = "+native" and options("is-main": true). Use moon build path --target native and moon test --target native for verification.
  #|- The async filesystem package provides @fs.read_file(path).text(), @fs.write_file(path, data, create_mode=CreateOrTruncate), and @fs.open(path, mode=ReadOnly/WriteOnly). The async process package provides @process.collect_output_merged(program, args, cwd=...).
  #|- Keep MoonBit code idiomatic: prefer existing package style, explicit types on public structs, concise error messages, and small helpers over broad rewrites.

///|
const MOONBIT_AGENT_GUIDE : String =
  #|Embedded guide source: ~/Documents/moonbit-agent-guide/moonbit-agent-guide.
  #|
  #|Agent workflow:
  #|1. Clarify expected behavior, non-goals, compatibility constraints, target backend, public API stability, and performance limits.
  #|2. Locate module/package boundaries. Find moon.mod.json for the module root and moon.pkg files for package boundaries and imports.
  #|3. Discover APIs before coding. Prefer moon ide doc queries to discover existing functions, types, and methods before adding new code. Use moon ide outline, peek-def, hover, find-references, rename, and analyze for semantic navigation and refactoring.
  #|4. Edit minimally and package-locally. Keep changes inside the right package, use ///| top-level delimiters, and split code into cohesive files.
  #|5. Validate in a tight loop. Run moon check after edits, targeted moon test, moon fmt, and moon info to verify public API changes.
  #|
  #|Fast playbooks:
  #|- Bug fix: reproduce or identify failing behavior, locate symbols with moon ide, implement the smallest package-local fix, then run moon check, targeted moon test, moon fmt, and moon info.
  #|- Refactor: confirm behavior/API invariants, prefer moon ide rename/find-references/peek-def, keep edits file-organization-focused, and verify pkg.generated.mbti is unchanged unless API change is intended.
  #|- New feature/public API: discover existing idioms with moon ide doc, add cohesive implementation, add black-box tests and docstring examples for public APIs, then review moon info output.
  #|
  #|Project layout:
  #|- A MoonBit module is rooted by moon.mod.json. A package is a directory with moon.pkg. Package names come from module name plus package path, not file names.
  #|- All .mbt files in one package form one compilation unit and share definitions. File names are organizational only and do not create namespaces.
  #|- Move declarations freely within the same package. Keep code in small cohesive files rather than giant impl/misc/util files.
  #|- Tests live in *_test.mbt or *_wbtest.mbt. README.mbt.md and docstring mbt check blocks are also checked/tested.
  #|- pkg.generated.mbti is generated by moon info and records the public API. Review it before handoff.
  #|
  #|Common pitfalls:
  #|- Variables/functions are lower_snake; types and enum variants are UpperCamel. Uppercase variables/functions are invalid.
  #|- Use mut only for rebinding local variables or mutable struct fields. Arrays/maps can mutate their contents without a mut binding.
  #|- Do not add await. Async is indicated by async fn or async test, and async calls are made directly.
  #|- Do not use ++ or --; use i = i + 1 or i += 1.
  #|- Do not add explicit try when merely propagating a raising function. Errors propagate automatically from functions declared raise.
  #|- Legacy function_name!(...) and function_name(...)? syntax is deprecated.
  #|- Prefer range loops such as for i in 0..<n and for i in 0..=n over C-style loops when practical.
  #|
  #|Moon essentials:
  #|- moon run cmd/main runs an executable package. moon build, moon check, moon info, and moon test all support --target.
  #|- Use moon check regularly because it is fast. Use moon test [dirname|filename] --filter 'glob' for targeted tests. Use moon test --update for snapshot updates.
  #|- moon explain --diagnostics lists compiler diagnostics and moon explain --diagnostics <id-or-name> explains one.
  #|- moon fmt rewrites files. moon -C dir check runs a command from a specific directory.
  #|
  #|README/doc/testing:
  #|- README.mbt.md and docstring ```mbt check``` blocks are type checked and tested. Use mbt nocheck only for examples that should not be checked.
  #|- Snapshot tests use inspect(value, content="..."). If output is unknown, write inspect(value), run moon test --update, and review the diff.
  #|- Use @json.inspect for nested structures; derive ToJson on test data. Prefer black-box tests via public APIs; use wbtest only for private internals.
  #|- Panic tests should be named with prefix "panic"; use ignore(...) if the panicking expression returns a value.
  #|- For raising functions, use try? f() to inspect Result values in tests.
  #|
  #|moon ide guide:
  #|- moon ide doc <query>: search APIs and symbols. Empty query lists available packages/symbols depending on context. Queries include "String", "String::*rev*", "@json", "@pkg.Type", and "@pkg.Type::method".
  #|- moon ide outline <dir|file>: list top-level symbols.
  #|- moon ide peek-def <symbol> [--loc path:line:col]: inspect definitions.
  #|- moon ide find-references <symbol> [--loc path:line:col]: locate usages.
  #|- moon ide hover <symbol> --loc path:line:col: show type/doc information.
  #|- moon ide rename <symbol> <new_name> [--loc path:line:col]: semantic rename. Prefer --loc when names are ambiguous.
  #|- moon ide analyze [path]: inspect public API usage when planning refactors.
  #|
  #|Language fundamentals:
  #|- Top-level declarations are separated by ///|. Functions are mutually recursive by default.
  #|- Function syntax: fn name(x : Type, labeled~ : Type, optional? : Type = default) -> Return raise ErrorType { body }. Use plain raise when exact error type is not important.
  #|- Methods are declared as Type::method(self : Type, ...). Static methods omit self. Trait impls use impl Trait for Type with method(self, ...) { ... } or pub impl for exported impls.
  #|- MoonBit is expression-oriented. if, match, blocks, and loops can return values. Last expression is the return value; return is often unnecessary.
  #|- Option is Some(value) or None. Results are Ok(value) and Err(error). Pattern matching supports arrays, structs, enums, strings, guards, and rest patterns.
  #|- Checked errors use suberror declarations and raise. Use try! to abort on error, try? to convert to Result, and catch blocks to handle.
  #|- Visibility: fn is package-private. pub exposes the type/API but may keep construction restricted. pub(all) allows external construction/read. pub(open) traits can be implemented outside the package.
  #|- Structs can have mutable fields with mut field : Type. Struct literals use Type::{ field: value } when needed; type prefix can be omitted when inferred.
  #|- Enums can derive Show, Eq, Compare, ToJson, Hash. Prefer deriving Show and Eq on data types; add ToJson for json snapshot tests.
  #|- Arrays/maps/structs have reference semantics. let mut is for reassigning a binding, not for mutating array elements or mutable fields.
  #|- String is immutable UTF-16. s[i] returns UInt16; s.get_char(i) returns Char?. Use char iteration for Unicode-safe traversal. Use @utf8.encode/decode for bytes.
  #|- String interpolation uses \{expr}; expressions inside interpolation must be simple and cannot contain string literals. Use StringBuilder for assembled text.
  #|- Multiline strings use #| with no escapes, or $| when interpolation is needed.
  #|- Functional loop requires a payload: loop (state) { pattern => ..., other => continue (new_state) }. Use while true for infinite loops.
  #|
  #|Async IO:
  #|- Use moonbitlang/async on native. Add dependency in moon.mod.json and import subpackages in moon.pkg.
  #|- Executables using async define async fn main. There is no await keyword.
  #|- Use @async.with_task_group for structured concurrency. When it returns, spawned tasks have terminated. Peer failures cancel the group unless allow_failure is used.
  #|- Closure syntax for spawn_bg/spawn: prefer () => { ... }; async fn() { ... } is also valid. Do not write async () => ...
  #|- Async tests use async test and should run with --target native unless the module's preferred target is native.
  #|
  #|Build/package configuration:
  #|- moon.pkg imports look like import { "username/module/pkg", "moonbitlang/x/encoding" @enc }. Code calls imports through @alias.function().
  #|- Packages without moon.pkg are not recognized. Commands use options("is-main": true) and often supported_targets = "+native".
  #|- Conditional compilation can target native, wasm, wasm-gc, js, debug, release, and logical and/or/not.
  #|- For native linking, moon.pkg options can configure link native cc, cc-flags, cc-link-flags, native-stub, and target-specific files.

///|
fn system_prompt() -> String {
  SYSTEM_PROMPT + "\n\n" + MOONBIT_AGENT_GUIDE
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
fn default_config() -> Config {
  {
    model_path: "",
    task: "",
    cwd: match @env.current_dir() {
      Some(path) => path
      None => "."
    },
    ctx_size: 32768,
    n_predict: 4096,
    max_turns: 16,
    temperature: 0.2,
    top_p: 0.95,
    seed: 0,
    backend: @ds4lib.Backend::default(),
    think_mode: @ds4lib.ThinkMode::high(),
  }
}

///|
fn parse_positive_int(value : String, opt : String) -> Int raise CliError {
  let parsed = @string.parse_int(value) catch {
    _ => raise CliError::Message("ds4mbt: invalid value for " + opt + ": " + value)
  }
  if parsed <= 0 {
    raise CliError::Message("ds4mbt: invalid value for " + opt + ": " + value)
  }
  parsed
}

///|
fn parse_uint64(value : String, opt : String) -> UInt64 raise CliError {
  let parsed = @string.parse_uint64(value) catch {
    _ => raise CliError::Message("ds4mbt: invalid value for " + opt + ": " + value)
  }
  if parsed == 0 {
    raise CliError::Message("ds4mbt: invalid value for " + opt + ": " + value)
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
    _ => raise CliError::Message("ds4mbt: invalid value for " + opt + ": " + value)
  }
  if parsed < min || parsed > max {
    raise CliError::Message("ds4mbt: invalid value for " + opt + ": " + value)
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
    raise CliError::Message("ds4mbt: invalid backend: " + value)
  }
}

///|
fn cli_command() -> @argparse.Command {
  @argparse.Command::new(
    "ds4mbt",
    about="Run a MoonBit coding micro agent through the DS4 MoonBit binding.",
    arg_required_else_help=true,
    options=[
      @argparse.OptionArg::new(
        "task",
        short='p',
        long="prompt",
        about="Coding task for the agent.",
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
        "cwd",
        long="cwd",
        about="Workspace directory for relative tools.",
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
        about="Maximum generated tokens per agent turn.",
        default_values=["4096"],
        allow_hyphen_values=true,
      ),
      @argparse.OptionArg::new(
        "max_turns",
        long="max-turns",
        about="Maximum tool/assistant turns.",
        default_values=["16"],
        allow_hyphen_values=true,
      ),
      @argparse.OptionArg::new(
        "temp",
        long="temp",
        about="Sampling temperature.",
        default_values=["0.2"],
        allow_hyphen_values=true,
      ),
      @argparse.OptionArg::new(
        "top_p",
        long="top-p",
        about="Nucleus sampling probability.",
        default_values=["0.95"],
        allow_hyphen_values=true,
      ),
      @argparse.OptionArg::new(
        "seed",
        long="seed",
        about="Sampling seed. Omit for time-based.",
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
    ],
    groups=[
      @argparse.ArgGroup::new("input", required=true, multiple=false, args=[
        "task",
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
  if option_value(matches, "task") is Some(value) {
    config = { ..config, task: value }
  }
  if option_value(matches, "model") is Some(value) {
    config = { ..config, model_path: value }
  }
  if option_value(matches, "cwd") is Some(value) {
    config = { ..config, cwd: value }
  }
  if option_value(matches, "ctx") is Some(value) {
    config = { ..config, ctx_size: parse_positive_int(value, "--ctx") }
  }
  if option_value(matches, "tokens") is Some(value) {
    config = { ..config, n_predict: parse_positive_int(value, "--tokens") }
  }
  if option_value(matches, "max_turns") is Some(value) {
    config = { ..config, max_turns: parse_positive_int(value, "--max-turns") }
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
  config
}

///|
fn parse_args(args : Array[String]) -> Config raise Error {
  let argv = if args.length() > 0 { args[1:] } else { args[:] }
  let matches = cli_command().parse(argv~, env=@env.get_env_vars())
  config_from_matches(matches)
}

///|
fn path_in_cwd(cwd : String, path : String) -> String {
  if path.has_prefix("/") {
    path
  } else if cwd.has_suffix("/") {
    cwd + path
  } else {
    cwd + "/" + path
  }
}

///|
fn truncate_output(text : String, limit : Int) -> String {
  if text.length() <= limit {
    text
  } else {
    text[:limit].to_owned() + "\n...[truncated]"
  }
}

///|
fn line_count(text : String) -> Int {
  text.split("\n").to_array().length()
}

///|
fn line_numbered_text(text : String, start_line : Int, end_line : Int) -> String {
  let lines = text.split("\n").to_array()
  let total = lines.length()
  let start = if start_line <= 0 { 1 } else { start_line }
  let end = if end_line <= 0 || end_line > total { total } else { end_line }
  let out = StringBuilder::new(size_hint=text.length() + total * 8)
  if start > total || start > end {
    out.write_string("(no lines in requested range)")
    return out.to_string()
  }
  for i in start..=end {
    out.write_string(i.to_string())
    out.write_string(" | ")
    out.write_stringview(lines[i - 1])
    out.write_string("\n")
  }
  out.to_string()
}

///|
fn first_line_of_match(text : String, needle : String) -> Int? {
  match text.find(needle) {
    None => None
    Some(index) => {
      let prefix = text[:index].to_owned()
      Some(line_count(prefix))
    }
  }
}

///|
fn parse_tools(text : String) -> Array[ToolCall] {
  let calls : Array[ToolCall] = []
  let mut rest = text[:]
  while rest.length() > 0 {
    match rest.find(TOOL_BEGIN) {
      None => break
      Some(begin) => {
        let after_begin = rest.view(start_offset=begin + TOOL_BEGIN.length())
        match after_begin.find(">") {
          None => break
          Some(close_name) => {
            let name = after_begin[:close_name].trim().to_owned()
            let after_name = after_begin.view(start_offset=close_name + 1)
            match after_name.find(TOOL_END) {
              None => break
              Some(end_index) => {
                calls.push({
                  name,
                  body: after_name[:end_index].trim().to_owned(),
                })
                rest = after_name.view(start_offset=end_index + TOOL_END.length())
              }
            }
          }
        }
      }
    }
  }
  calls
}

///|
fn split_body_2(body : String) -> (String, String)? {
  match body.split_once("\n---\n") {
    None => None
    Some((a, b)) => Some((a.trim().to_owned(), b.to_owned()))
  }
}

///|
fn parse_int_opt(value : String) -> Int? {
  let parsed = @string.parse_int(value) catch {
    _ => return None
  }
  if parsed <= 0 { None } else { Some(parsed) }
}

///|
fn parse_read_request_opt(body : String) -> ReadRequest? {
  match body.split_once("\n---\n") {
    None => Some({ path: body.trim().to_owned(), start_line: 0, end_line: 0 })
    Some((path, rest)) =>
      match rest.split_once("\n---\n") {
        None => None
        Some((start, end)) => {
          match (parse_int_opt(start.trim().to_owned()), parse_int_opt(end.trim().to_owned())) {
            (Some(start_line), Some(end_line)) if end_line >= start_line =>
              Some({ path: path.trim().to_owned(), start_line, end_line })
            _ => None
          }
        }
      }
  }
}

///|
fn parse_read_request(body : String) -> ReadRequest raise CliError {
  match parse_read_request_opt(body) {
    Some(request) => request
    None =>
      raise CliError::Message(
        "read error: expected path or path, start line, and end line",
      )
  }
}

///|
fn split_body_3(body : String) -> (String, String, String)? {
  match body.split_once("\n---\n") {
    None => None
    Some((path, rest)) =>
      match rest.split_once("\n---\n") {
        None => None
        Some((old_text, new_text)) =>
          Some((
            path.trim().to_owned(),
            old_text.to_owned(),
            new_text.to_owned(),
          ))
      }
  }
}

///|
fn tool_summary(call : ToolCall) -> String {
  match call.name {
    "read" =>
      match parse_read_request_opt(call.body) {
        None => "read <invalid>"
        Some(request) =>
          if request.start_line == 0 {
            "read " + request.path
          } else {
            "read " + request.path + ":" + request.start_line.to_string() +
            "-" + request.end_line.to_string()
          }
      }
    "write" =>
      match split_body_2(call.body) {
        Some((path, _)) => "write " + path
        None => "write <invalid>"
      }
    "edit" =>
      match split_body_3(call.body) {
        Some((path, _, _)) => "edit " + path
        None => "edit <invalid>"
      }
    "bash" => "bash " + call.body.trim().to_owned()
    other => other
  }
}

///|
async fn run_tool(config : Config, call : ToolCall) -> String raise Error {
  match call.name {
    "read" => {
      let request = parse_read_request(call.body)
      let full_path = path_in_cwd(config.cwd, request.path)
      match @fs.kind(full_path) {
        @fs.Directory => {
          let entries = @fs.readdir(
            full_path,
            include_hidden=true,
            include_special=false,
            sort=true,
          )
          "read " + request.path + " directory\n" + entries.join("\n")
        }
        _ => {
          let text = @fs.read_file(full_path).text()
          let rendered = line_numbered_text(
            text,
            request.start_line,
            request.end_line,
          )
          let range = if request.start_line > 0 {
            " lines " + request.start_line.to_string() + "-" +
            request.end_line.to_string()
          } else {
            ""
          }
          "read " + request.path + range + "\n" +
          truncate_output(rendered, 20000)
        }
      }
    }
    "write" =>
      match split_body_2(call.body) {
        None => "write error: expected path, separator, and complete contents"
        Some((path, content)) => {
          @fs.write_file(
            path_in_cwd(config.cwd, path),
            content,
            create_mode=@fs.CreateOrTruncate,
          )
          "write " + path + " lines 1-" + line_count(content).to_string() +
          ": ok"
        }
      }
    "edit" =>
      match split_body_3(call.body) {
        None => "edit error: expected path, old text, and replacement text"
        Some((path, old_text, new_text)) => {
          let full_path = path_in_cwd(config.cwd, path)
          let original = @fs.read_file(full_path).text()
          let line = first_line_of_match(original, old_text)
          let replaced = original.replace(old=old_text, new=new_text)
          if replaced == original {
            "edit " + path + ": old text not found"
          } else {
            @fs.write_file(full_path, replaced, create_mode=@fs.CreateOrTruncate)
            match line {
              Some(n) => "edit " + path + " line " + n.to_string() + ": ok"
              None => "edit " + path + ": ok"
            }
          }
        }
    }
    "bash" => {
      let command = call.body.trim().to_owned()
      let (code, output) = @process.collect_output_merged(
        "bash",
        ["-lc", command],
        cwd=config.cwd,
      )
      "bash exit " + code.to_string() + "\n" +
      truncate_output(output.text(), 20000)
    }
    other => "tool error: unknown tool " + other
  }
}

///|
async fn run_tools_parallel(
  config : Config,
  calls : Array[ToolCall],
) -> Array[String] raise Error {
  let tasks : Array[async () -> String] = []
  for call in calls {
    let captured = call
    tasks.push(() => {
      run_tool(config, captured) catch {
        err => "tool " + tool_summary(captured) + " error: " + err.to_string()
      }
    })
  }
  @async.all(tasks[:])
}

///|
async fn generate_once(
  engine : @ds4lib.Engine,
  sampler : @ds4lib.Sampler,
  config : Config,
  prompt_text : String,
  stdout : @io.BufferedWriter[@stdio.Output],
) -> String raise Error {
  let think_mode = config.think_mode.for_context(config.ctx_size)
  let prompt = engine.encode_chat_prompt(
    prompt_text,
    system=system_prompt(),
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
  let out = StringBuilder::new(size_hint=4096)
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
    let piece = engine.token_text(token)
    out.write_string(piece)
    stdout.write(renderer.render_piece(piece))
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
  out.to_string()
}

///|
async fn run_agent(config : Config) -> Unit raise Error {
  let engine = @ds4lib.Engine::open(
    @ds4lib.EngineConfig::new(config.model_path, backend=config.backend),
  )
  let sampler = @ds4lib.Sampler::new(
    if config.seed == 0 {
      @env.now()
    } else {
      config.seed
    },
  )
  let stdout = @io.BufferedWriter::new(@stdio.stdout, size=4096)
  let mut transcript = "Task:\n" + config.task + "\n\nWorkspace: " + config.cwd
  let mut turn = 0
  while turn < config.max_turns {
    stdout.write("[thinking turn " + (turn + 1).to_string() + "]\n")
    stdout.flush()
    let response = generate_once(engine, sampler, config, transcript, stdout)
    let calls = parse_tools(response)
    if calls.length() == 0 {
      return
    }
    for call in calls {
      stdout.write("[" + tool_summary(call) + "]\n")
    }
    stdout.flush()
    let observations = run_tools_parallel(config, calls)
    for observation in observations {
      stdout.write(observation)
      if !observation.has_suffix("\n") {
        stdout.write("\n")
      }
      stdout.flush()
    }
    transcript = transcript + "\n\nAssistant:\n" + response +
      "\n\nObservations:\n" + observations.join("\n\n")
    turn = turn + 1
  }
  stdout.write("ds4mbt: stopped after max turns\n")
  stdout.flush()
}

///|
async fn main raise Error {
  let config = parse_args(@env.args())
  run_agent(config)
}
