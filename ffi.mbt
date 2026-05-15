///|
struct Backend(Int) derive(Eq, Debug)

///|
pub fn Backend::metal() -> Backend {
  Backend(0)
}

///|
pub fn Backend::cuda() -> Backend {
  Backend(1)
}

///|
pub fn Backend::cpu() -> Backend {
  Backend(2)
}

///|
extern "c" fn backend_default_ffi() -> Int = "moonbit_ds4_backend_default"

///|
pub fn Backend::default() -> Backend {
  Backend(backend_default_ffi())
}

///|
fn Backend::to_int(self : Backend) -> Int {
  self.0
}

///|
extern "c" fn backend_name_ffi(backend : Int) -> Bytes = "moonbit_ds4_backend_name"

///|
pub fn Backend::name(self : Backend) -> String {
  @utf8.decode_lossy(backend_name_ffi(self.0))
}

///|
struct ThinkMode(Int) derive(Eq, Debug)

///|
pub fn ThinkMode::none() -> ThinkMode {
  ThinkMode(0)
}

///|
pub fn ThinkMode::high() -> ThinkMode {
  ThinkMode(1)
}

///|
pub fn ThinkMode::max() -> ThinkMode {
  ThinkMode(2)
}

///|
fn ThinkMode::to_int(self : ThinkMode) -> Int {
  self.0
}

///|
extern "c" fn think_mode_name_ffi(mode : Int) -> Bytes = "moonbit_ds4_think_mode_name"

///|
pub fn ThinkMode::name(self : ThinkMode) -> String {
  @utf8.decode_lossy(think_mode_name_ffi(self.0))
}

///|
extern "c" fn think_mode_enabled_ffi(mode : Int) -> Bool = "moonbit_ds4_think_mode_enabled"

///|
pub fn ThinkMode::enabled(self : ThinkMode) -> Bool {
  think_mode_enabled_ffi(self.0)
}

///|
extern "c" fn think_max_prefix_ffi() -> Bytes = "moonbit_ds4_think_max_prefix"

///|
pub fn ThinkMode::max_prefix() -> String {
  @utf8.decode_lossy(think_max_prefix_ffi())
}

///|
extern "c" fn think_max_min_context_ffi() -> UInt = "moonbit_ds4_think_max_min_context"

///|
pub fn ThinkMode::max_min_context() -> UInt {
  think_max_min_context_ffi()
}

///|
extern "c" fn think_mode_for_context_ffi(mode : Int, ctx_size : Int) -> Int = "moonbit_ds4_think_mode_for_context"

///|
pub fn ThinkMode::for_context(self : ThinkMode, ctx_size : Int) -> ThinkMode {
  ThinkMode(think_mode_for_context_ffi(self.0, ctx_size))
}

///|
pub(all) struct ContextMemory {
  total_bytes : UInt64
  raw_bytes : UInt64
  compressed_bytes : UInt64
  scratch_bytes : UInt64
  prefill_cap : UInt
  raw_cap : UInt
  comp_cap : UInt
} derive(Eq, Debug)

///|
extern "c" fn context_memory_total_ffi(backend : Int, ctx_size : Int) -> UInt64 = "moonbit_ds4_context_memory_total"

///|
extern "c" fn context_memory_raw_ffi(backend : Int, ctx_size : Int) -> UInt64 = "moonbit_ds4_context_memory_raw"

///|
extern "c" fn context_memory_compressed_ffi(
  backend : Int,
  ctx_size : Int,
) -> UInt64 = "moonbit_ds4_context_memory_compressed"

///|
extern "c" fn context_memory_scratch_ffi(
  backend : Int,
  ctx_size : Int,
) -> UInt64 = "moonbit_ds4_context_memory_scratch"

///|
extern "c" fn context_memory_prefill_cap_ffi(
  backend : Int,
  ctx_size : Int,
) -> UInt = "moonbit_ds4_context_memory_prefill_cap"

///|
extern "c" fn context_memory_raw_cap_ffi(backend : Int, ctx_size : Int) -> UInt = "moonbit_ds4_context_memory_raw_cap"

///|
extern "c" fn context_memory_comp_cap_ffi(
  backend : Int,
  ctx_size : Int,
) -> UInt = "moonbit_ds4_context_memory_comp_cap"

///|
pub fn Backend::context_memory_estimate(
  self : Backend,
  ctx_size : Int,
) -> ContextMemory {
  let backend = self.0
  {
    total_bytes: context_memory_total_ffi(backend, ctx_size),
    raw_bytes: context_memory_raw_ffi(backend, ctx_size),
    compressed_bytes: context_memory_compressed_ffi(backend, ctx_size),
    scratch_bytes: context_memory_scratch_ffi(backend, ctx_size),
    prefill_cap: context_memory_prefill_cap_ffi(backend, ctx_size),
    raw_cap: context_memory_raw_cap_ffi(backend, ctx_size),
    comp_cap: context_memory_comp_cap_ffi(backend, ctx_size),
  }
}

///|
pub(all) suberror Ds4Error {
  OpenFailed(Int)
  SessionCreateFailed(Int, String)
  OperationFailed(op~ : String, status~ : Int, message~ : String)
} derive(Eq, Debug)

///|
pub(all) struct EngineConfig {
  model_path : String
  mtp_path : String
  backend : Backend
  n_threads : Int
  mtp_draft_tokens : Int
  mtp_margin : Float
  directional_steering_file : String
  directional_steering_attn : Float
  directional_steering_ffn : Float
  warm_weights : Bool
  quality : Bool
} derive(Eq, Debug)

///|
pub fn EngineConfig::new(
  model_path : String,
  backend? : Backend = Backend::default(),
  mtp_path? : String = "",
  n_threads? : Int = 0,
  mtp_draft_tokens? : Int = 1,
  mtp_margin? : Float = -1.0,
  directional_steering_file? : String = "",
  directional_steering_attn? : Float = 0.0,
  directional_steering_ffn? : Float = 0.0,
  warm_weights? : Bool = false,
  quality? : Bool = false,
) -> EngineConfig {
  {
    model_path,
    mtp_path,
    backend,
    n_threads,
    mtp_draft_tokens,
    mtp_margin,
    directional_steering_file,
    directional_steering_attn,
    directional_steering_ffn,
    warm_weights,
    quality,
  }
}

///|
type Engine

///|
type Session

///|
type Tokens

///|
type Sampler

///|
#borrow(model_path, mtp_path, directional_steering_file)
extern "c" fn engine_open_ffi(
  model_path : Bytes,
  mtp_path : Bytes,
  backend : Int,
  n_threads : Int,
  mtp_draft_tokens : Int,
  mtp_margin : Float,
  directional_steering_file : Bytes,
  directional_steering_attn : Float,
  directional_steering_ffn : Float,
  warm_weights : Bool,
  quality : Bool,
) -> Engine = "moonbit_ds4_engine_open"

///|
#borrow(engine)
extern "c" fn engine_status_ffi(engine : Engine) -> Int = "moonbit_ds4_engine_status"

///|
pub fn Engine::status(self : Engine) -> Int {
  engine_status_ffi(self)
}

///|
pub fn Engine::is_open(self : Engine) -> Bool {
  self.status() == 0
}

///|
pub fn Engine::open(config : EngineConfig) -> Engine raise Ds4Error {
  let engine = engine_open_ffi(
    @utf8.encode(config.model_path),
    @utf8.encode(config.mtp_path),
    config.backend.to_int(),
    config.n_threads,
    config.mtp_draft_tokens,
    config.mtp_margin,
    @utf8.encode(config.directional_steering_file),
    config.directional_steering_attn,
    config.directional_steering_ffn,
    config.warm_weights,
    config.quality,
  )
  let status = engine.status()
  if status != 0 {
    raise Ds4Error::OpenFailed(status)
  }
  engine
}

///|
#borrow(engine)
extern "c" fn engine_summary_ffi(engine : Engine) -> Unit = "moonbit_ds4_engine_summary"

///|
pub fn Engine::summary(self : Engine) -> Unit {
  engine_summary_ffi(self)
}

///|
#borrow(engine)
extern "c" fn engine_token_eos_ffi(engine : Engine) -> Int = "moonbit_ds4_engine_token_eos"

///|
pub fn Engine::token_eos(self : Engine) -> Int {
  engine_token_eos_ffi(self)
}

///|
#borrow(engine)
extern "c" fn engine_routed_quant_bits_ffi(engine : Engine) -> Int = "moonbit_ds4_engine_routed_quant_bits"

///|
pub fn Engine::routed_quant_bits(self : Engine) -> Int {
  engine_routed_quant_bits_ffi(self)
}

///|
#borrow(engine)
extern "c" fn engine_has_mtp_ffi(engine : Engine) -> Bool = "moonbit_ds4_engine_has_mtp"

///|
pub fn Engine::has_mtp(self : Engine) -> Bool {
  engine_has_mtp_ffi(self)
}

///|
#borrow(engine)
extern "c" fn engine_mtp_draft_tokens_ffi(engine : Engine) -> Int = "moonbit_ds4_engine_mtp_draft_tokens"

///|
pub fn Engine::mtp_draft_tokens(self : Engine) -> Int {
  engine_mtp_draft_tokens_ffi(self)
}

///|
#borrow(engine)
extern "c" fn engine_token_text_ffi(engine : Engine, token : Int) -> Bytes = "moonbit_ds4_engine_token_text"

///|
pub fn Engine::token_text(self : Engine, token : Int) -> String {
  @utf8.decode_lossy(engine_token_text_ffi(self, token))
}

///|
extern "c" fn tokens_new_ffi() -> Tokens = "moonbit_ds4_tokens_new"

///|
pub fn Tokens::new() -> Tokens {
  tokens_new_ffi()
}

///|
extern "c" fn sampler_new_ffi(seed : UInt64) -> Sampler = "moonbit_ds4_sampler_new"

///|
pub fn Sampler::new(seed : UInt64) -> Sampler {
  sampler_new_ffi(seed)
}

///|
#borrow(tokens)
extern "c" fn tokens_copy_ffi(tokens : Tokens) -> Tokens = "moonbit_ds4_tokens_copy"

///|
pub fn Tokens::copy(self : Tokens) -> Tokens {
  tokens_copy_ffi(self)
}

///|
#borrow(tokens)
extern "c" fn tokens_push_ffi(tokens : Tokens, token : Int) -> Unit = "moonbit_ds4_tokens_push"

///|
pub fn Tokens::push(self : Tokens, token : Int) -> Unit {
  tokens_push_ffi(self, token)
}

///|
#borrow(tokens)
extern "c" fn tokens_length_ffi(tokens : Tokens) -> Int = "moonbit_ds4_tokens_length"

///|
pub fn Tokens::length(self : Tokens) -> Int {
  tokens_length_ffi(self)
}

///|
#borrow(tokens)
extern "c" fn tokens_get_ffi(tokens : Tokens, index : Int) -> Int = "moonbit_ds4_tokens_get"

///|
pub fn Tokens::get(self : Tokens, index : Int) -> Int? {
  if index < 0 || index >= self.length() {
    None
  } else {
    Some(tokens_get_ffi(self, index))
  }
}

///|
pub fn Tokens::op_get(self : Tokens, index : Int) -> Int {
  if index < 0 || index >= self.length() {
    abort("token index out of bounds")
  }
  tokens_get_ffi(self, index)
}

///|
#borrow(tokens)
extern "c" fn tokens_to_fixed_array_ffi(tokens : Tokens) -> FixedArray[Int] = "moonbit_ds4_tokens_to_fixed_array"

///|
pub fn Tokens::to_fixed_array(self : Tokens) -> FixedArray[Int] {
  tokens_to_fixed_array_ffi(self)
}

///|
#borrow(tokens, prefix)
extern "c" fn tokens_starts_with_ffi(tokens : Tokens, prefix : Tokens) -> Bool = "moonbit_ds4_tokens_starts_with"

///|
pub fn Tokens::starts_with(self : Tokens, prefix : Tokens) -> Bool {
  tokens_starts_with_ffi(self, prefix)
}

///|
#borrow(engine, text)
extern "c" fn engine_tokenize_text_ffi(engine : Engine, text : Bytes) -> Tokens = "moonbit_ds4_engine_tokenize_text"

///|
pub fn Engine::tokenize_text(self : Engine, text : StringView) -> Tokens {
  engine_tokenize_text_ffi(self, @utf8.encode(text))
}

///|
#borrow(engine, text)
extern "c" fn engine_tokenize_rendered_chat_ffi(
  engine : Engine,
  text : Bytes,
) -> Tokens = "moonbit_ds4_engine_tokenize_rendered_chat"

///|
pub fn Engine::tokenize_rendered_chat(
  self : Engine,
  text : StringView,
) -> Tokens {
  engine_tokenize_rendered_chat_ffi(self, @utf8.encode(text))
}

///|
#borrow(engine, system, prompt)
extern "c" fn engine_encode_chat_prompt_ffi(
  engine : Engine,
  system : Bytes,
  prompt : Bytes,
  think_mode : Int,
) -> Tokens = "moonbit_ds4_engine_encode_chat_prompt"

///|
pub fn Engine::encode_chat_prompt(
  self : Engine,
  system? : StringView = "",
  prompt : StringView,
  think_mode? : ThinkMode = ThinkMode::none(),
) -> Tokens {
  engine_encode_chat_prompt_ffi(
    self,
    @utf8.encode(system),
    @utf8.encode(prompt),
    think_mode.to_int(),
  )
}

///|
#borrow(engine, tokens)
extern "c" fn engine_chat_begin_ffi(engine : Engine, tokens : Tokens) -> Unit = "moonbit_ds4_engine_chat_begin"

///|
pub fn Engine::chat_begin(self : Engine, tokens : Tokens) -> Unit {
  engine_chat_begin_ffi(self, tokens)
}

///|
#borrow(engine, tokens)
extern "c" fn engine_chat_append_max_effort_prefix_ffi(
  engine : Engine,
  tokens : Tokens,
) -> Unit = "moonbit_ds4_engine_chat_append_max_effort_prefix"

///|
pub fn Engine::chat_append_max_effort_prefix(
  self : Engine,
  tokens : Tokens,
) -> Unit {
  engine_chat_append_max_effort_prefix_ffi(self, tokens)
}

///|
#borrow(engine, tokens, role, content)
extern "c" fn engine_chat_append_message_ffi(
  engine : Engine,
  tokens : Tokens,
  role : Bytes,
  content : Bytes,
) -> Unit = "moonbit_ds4_engine_chat_append_message"

///|
pub fn Engine::chat_append_message(
  self : Engine,
  tokens : Tokens,
  role? : StringView = "user",
  content : StringView,
) -> Unit {
  engine_chat_append_message_ffi(
    self,
    tokens,
    @utf8.encode(role),
    @utf8.encode(content),
  )
}

///|
#borrow(engine, tokens)
extern "c" fn engine_chat_append_assistant_prefix_ffi(
  engine : Engine,
  tokens : Tokens,
  think_mode : Int,
) -> Unit = "moonbit_ds4_engine_chat_append_assistant_prefix"

///|
pub fn Engine::chat_append_assistant_prefix(
  self : Engine,
  tokens : Tokens,
  think_mode? : ThinkMode = ThinkMode::none(),
) -> Unit {
  engine_chat_append_assistant_prefix_ffi(self, tokens, think_mode.to_int())
}

///|
#borrow(engine)
extern "c" fn session_create_ffi(engine : Engine, ctx_size : Int) -> Session = "moonbit_ds4_session_create"

///|
#borrow(session)
extern "c" fn session_status_ffi(session : Session) -> Int = "moonbit_ds4_session_status"

///|
#borrow(session)
extern "c" fn session_last_error_ffi(session : Session) -> Bytes = "moonbit_ds4_session_last_error"

///|
pub fn Session::status(self : Session) -> Int {
  session_status_ffi(self)
}

///|
pub fn Session::last_error(self : Session) -> String {
  @utf8.decode_lossy(session_last_error_ffi(self))
}

///|
pub fn Engine::create_session(
  self : Engine,
  ctx_size : Int,
) -> Session raise Ds4Error {
  let session = session_create_ffi(self, ctx_size)
  let status = session.status()
  if status != 0 {
    raise Ds4Error::SessionCreateFailed(status, session.last_error())
  }
  session
}

///|
#borrow(session, prompt)
extern "c" fn session_sync_ffi(session : Session, prompt : Tokens) -> Int = "moonbit_ds4_session_sync"

///|
pub fn Session::sync(self : Session, prompt : Tokens) -> Unit raise Ds4Error {
  let status = session_sync_ffi(self, prompt)
  if status != 0 {
    raise Ds4Error::OperationFailed(
      op="sync",
      status~,
      message=self.last_error(),
    )
  }
}

///|
#borrow(session)
extern "c" fn session_eval_ffi(session : Session, token : Int) -> Int = "moonbit_ds4_session_eval"

///|
pub fn Session::eval(self : Session, token : Int) -> Unit raise Ds4Error {
  let status = session_eval_ffi(self, token)
  if status != 0 {
    raise Ds4Error::OperationFailed(
      op="eval",
      status~,
      message=self.last_error(),
    )
  }
}

///|
#borrow(session)
extern "c" fn session_argmax_ffi(session : Session) -> Int = "moonbit_ds4_session_argmax"

///|
pub fn Session::argmax(self : Session) -> Int {
  session_argmax_ffi(self)
}

///|
#borrow(session)
extern "c" fn session_argmax_excluding_ffi(
  session : Session,
  excluded_id : Int,
) -> Int = "moonbit_ds4_session_argmax_excluding"

///|
pub fn Session::argmax_excluding(self : Session, excluded_id : Int) -> Int {
  session_argmax_excluding_ffi(self, excluded_id)
}

///|
#borrow(session, sampler)
extern "c" fn session_sample_ffi(
  session : Session,
  temperature : Float,
  top_k : Int,
  top_p : Float,
  min_p : Float,
  sampler : Sampler,
) -> Int = "moonbit_ds4_session_sample"

///|
pub fn Session::sample(
  self : Session,
  sampler : Sampler,
  temperature? : Float = 1.0,
  top_k? : Int = 0,
  top_p? : Float = 1.0,
  min_p? : Float = 0.0,
) -> Int {
  session_sample_ffi(self, temperature, top_k, top_p, min_p, sampler)
}

///|
#borrow(session)
extern "c" fn session_invalidate_ffi(session : Session) -> Unit = "moonbit_ds4_session_invalidate"

///|
pub fn Session::invalidate(self : Session) -> Unit {
  session_invalidate_ffi(self)
}

///|
#borrow(session)
extern "c" fn session_rewind_ffi(session : Session, pos : Int) -> Unit = "moonbit_ds4_session_rewind"

///|
pub fn Session::rewind(self : Session, pos : Int) -> Unit {
  session_rewind_ffi(self, pos)
}

///|
#borrow(session)
extern "c" fn session_pos_ffi(session : Session) -> Int = "moonbit_ds4_session_pos"

///|
pub fn Session::pos(self : Session) -> Int {
  session_pos_ffi(self)
}

///|
#borrow(session)
extern "c" fn session_ctx_ffi(session : Session) -> Int = "moonbit_ds4_session_ctx"

///|
pub fn Session::ctx(self : Session) -> Int {
  session_ctx_ffi(self)
}

///|
#borrow(session)
extern "c" fn session_tokens_ffi(session : Session) -> Tokens = "moonbit_ds4_session_tokens"

///|
pub fn Session::tokens(self : Session) -> Tokens {
  session_tokens_ffi(self)
}
