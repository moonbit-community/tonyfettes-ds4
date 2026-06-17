#include "moonbit.h"
#include "ds4.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  ds4_engine *ptr;
} MoonBitDS4Engine;

typedef struct {
  ds4_session *ptr;
  MoonBitDS4Engine *engine;
} MoonBitDS4Session;

typedef struct {
  ds4_tokens value;
} MoonBitDS4Tokens;

typedef struct {
  uint64_t state;
} MoonBitDS4Sampler;

static moonbit_bytes_t mb_copy_bytes(const char *ptr, size_t len) {
  moonbit_bytes_t out = moonbit_make_bytes((int32_t)len, 0);
  if (len > 0) {
    memcpy(out, ptr, len);
  }
  return out;
}

static moonbit_bytes_t mb_copy_cstr(const char *ptr) {
  return mb_copy_bytes(ptr, strlen(ptr));
}

static void engine_finalize(void *obj) {
  MoonBitDS4Engine *engine = (MoonBitDS4Engine *)obj;
  if (engine->ptr) {
    ds4_engine_close(engine->ptr);
    engine->ptr = NULL;
  }
}

static void session_finalize(void *obj) {
  MoonBitDS4Session *session = (MoonBitDS4Session *)obj;
  if (session->ptr) {
    ds4_session_free(session->ptr);
    session->ptr = NULL;
  }
  if (session->engine) {
    moonbit_decref(session->engine);
    session->engine = NULL;
  }
}

static void tokens_finalize(void *obj) {
  MoonBitDS4Tokens *tokens = (MoonBitDS4Tokens *)obj;
  ds4_tokens_free(&tokens->value);
}

static void sampler_finalize(void *obj) {
  (void)obj;
}

static MoonBitDS4Tokens *tokens_new_raw(void) {
  MoonBitDS4Tokens *tokens = (MoonBitDS4Tokens *)moonbit_make_external_object(
    tokens_finalize,
    sizeof(MoonBitDS4Tokens)
  );
  tokens->value.v = NULL;
  tokens->value.len = 0;
  tokens->value.cap = 0;
  return tokens;
}

static MoonBitDS4Sampler *sampler_new_raw(uint64_t seed) {
  MoonBitDS4Sampler *sampler = (MoonBitDS4Sampler *)moonbit_make_external_object(
    sampler_finalize,
    sizeof(MoonBitDS4Sampler)
  );
  sampler->state = seed;
  return sampler;
}

static MoonBitDS4Engine *engine_new_raw(void) {
  MoonBitDS4Engine *engine = (MoonBitDS4Engine *)moonbit_make_external_object(
    engine_finalize,
    sizeof(MoonBitDS4Engine)
  );
  engine->ptr = NULL;
  return engine;
}

static MoonBitDS4Session *session_new_raw(void) {
  MoonBitDS4Session *session = (MoonBitDS4Session *)moonbit_make_external_object(
    session_finalize,
    sizeof(MoonBitDS4Session)
  );
  session->ptr = NULL;
  session->engine = NULL;
  return session;
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_backend_default(void) {
#if defined(__APPLE__)
  return DS4_BACKEND_METAL;
#else
  return DS4_BACKEND_CUDA;
#endif
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moonbit_ds4_backend_name(int32_t backend) {
  return mb_copy_cstr(ds4_backend_name((ds4_backend)backend));
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moonbit_ds4_think_mode_name(int32_t mode) {
  return mb_copy_cstr(ds4_think_mode_name((ds4_think_mode)mode));
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_think_mode_enabled(int32_t mode) {
  return (int32_t)ds4_think_mode_enabled((ds4_think_mode)mode);
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moonbit_ds4_think_max_prefix(void) {
  return mb_copy_cstr(ds4_think_max_prefix());
}

MOONBIT_FFI_EXPORT
uint32_t moonbit_ds4_think_max_min_context(void) {
  return ds4_think_max_min_context();
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_think_mode_for_context(int32_t mode, int32_t ctx_size) {
  return (int32_t)ds4_think_mode_for_context((ds4_think_mode)mode, ctx_size);
}

MOONBIT_FFI_EXPORT
uint64_t moonbit_ds4_context_memory_total(int32_t backend, int32_t ctx_size) {
  return ds4_context_memory_estimate((ds4_backend)backend, ctx_size).total_bytes;
}

MOONBIT_FFI_EXPORT
uint64_t moonbit_ds4_context_memory_raw(int32_t backend, int32_t ctx_size) {
  return ds4_context_memory_estimate((ds4_backend)backend, ctx_size).raw_bytes;
}

MOONBIT_FFI_EXPORT
uint64_t moonbit_ds4_context_memory_compressed(int32_t backend, int32_t ctx_size) {
  return ds4_context_memory_estimate((ds4_backend)backend, ctx_size).compressed_bytes;
}

MOONBIT_FFI_EXPORT
uint64_t moonbit_ds4_context_memory_scratch(int32_t backend, int32_t ctx_size) {
  return ds4_context_memory_estimate((ds4_backend)backend, ctx_size).scratch_bytes;
}

MOONBIT_FFI_EXPORT
uint32_t moonbit_ds4_context_memory_prefill_cap(int32_t backend, int32_t ctx_size) {
  return ds4_context_memory_estimate((ds4_backend)backend, ctx_size).prefill_cap;
}

MOONBIT_FFI_EXPORT
uint32_t moonbit_ds4_context_memory_raw_cap(int32_t backend, int32_t ctx_size) {
  return ds4_context_memory_estimate((ds4_backend)backend, ctx_size).raw_cap;
}

MOONBIT_FFI_EXPORT
uint32_t moonbit_ds4_context_memory_comp_cap(int32_t backend, int32_t ctx_size) {
  return ds4_context_memory_estimate((ds4_backend)backend, ctx_size).comp_cap;
}

MOONBIT_FFI_EXPORT
MoonBitDS4Engine *moonbit_ds4_engine_new(void) {
  return engine_new_raw();
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_engine_open(
  MoonBitDS4Engine *engine,
  moonbit_bytes_t model_path,
  moonbit_bytes_t mtp_path,
  int32_t backend,
  int32_t n_threads,
  int32_t mtp_draft_tokens,
  float mtp_margin,
  moonbit_bytes_t directional_steering_file,
  float directional_steering_attn,
  float directional_steering_ffn,
  int32_t warm_weights,
  int32_t quality,
  int32_t inspect_only
) {
  ds4_engine_options opt = {0};
  opt.model_path = (const char *)model_path;
  opt.mtp_path = (const char *)mtp_path;
  opt.backend = (ds4_backend)backend;
  opt.n_threads = n_threads;
  opt.mtp_draft_tokens = mtp_draft_tokens;
  opt.mtp_margin = mtp_margin;
  opt.directional_steering_file = (const char *)directional_steering_file;
  opt.directional_steering_attn = directional_steering_attn;
  opt.directional_steering_ffn = directional_steering_ffn;
  opt.warm_weights = warm_weights != 0;
  opt.quality = quality != 0;
  opt.inspect_only = inspect_only != 0;
  return ds4_engine_open(&engine->ptr, &opt);
}

MOONBIT_FFI_EXPORT
void moonbit_ds4_engine_summary(MoonBitDS4Engine *engine) {
  ds4_engine_summary(engine->ptr);
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_engine_token_eos(MoonBitDS4Engine *engine) {
  return ds4_token_eos(engine->ptr);
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_engine_routed_quant_bits(MoonBitDS4Engine *engine) {
  return ds4_engine_routed_quant_bits(engine->ptr);
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_engine_has_mtp(MoonBitDS4Engine *engine) {
  return (int32_t)ds4_engine_has_mtp(engine->ptr);
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_engine_mtp_draft_tokens(MoonBitDS4Engine *engine) {
  return ds4_engine_mtp_draft_tokens(engine->ptr);
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moonbit_ds4_engine_token_text(MoonBitDS4Engine *engine, int32_t token) {
  size_t len = 0;
  char *text = ds4_token_text(engine->ptr, token, &len);
  moonbit_bytes_t out = mb_copy_bytes(text, len);
  free(text);
  return out;
}

MOONBIT_FFI_EXPORT
MoonBitDS4Tokens *moonbit_ds4_tokens_new(void) {
  return tokens_new_raw();
}

MOONBIT_FFI_EXPORT
MoonBitDS4Sampler *moonbit_ds4_sampler_new(uint64_t seed) {
  return sampler_new_raw(seed);
}

MOONBIT_FFI_EXPORT
MoonBitDS4Tokens *moonbit_ds4_tokens_copy(MoonBitDS4Tokens *tokens) {
  MoonBitDS4Tokens *out = tokens_new_raw();
  ds4_tokens_copy(&out->value, &tokens->value);
  return out;
}

MOONBIT_FFI_EXPORT
void moonbit_ds4_tokens_push(MoonBitDS4Tokens *tokens, int32_t token) {
  ds4_tokens_push(&tokens->value, token);
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_tokens_length(MoonBitDS4Tokens *tokens) {
  return tokens->value.len;
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_tokens_get(MoonBitDS4Tokens *tokens, int32_t index) {
  return tokens->value.v[index];
}

MOONBIT_FFI_EXPORT
int32_t *moonbit_ds4_tokens_to_fixed_array(MoonBitDS4Tokens *tokens) {
  int32_t len = tokens->value.len;
  int32_t *out = moonbit_make_int32_array_raw(len);
  for (int32_t i = 0; i < len; i++) {
    out[i] = tokens->value.v[i];
  }
  return out;
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_tokens_starts_with(MoonBitDS4Tokens *tokens, MoonBitDS4Tokens *prefix) {
  return (int32_t)ds4_tokens_starts_with(&tokens->value, &prefix->value);
}

MOONBIT_FFI_EXPORT
MoonBitDS4Tokens *moonbit_ds4_engine_tokenize_text(MoonBitDS4Engine *engine, moonbit_bytes_t text) {
  MoonBitDS4Tokens *out = tokens_new_raw();
  ds4_tokenize_text(engine->ptr, (const char *)text, &out->value);
  return out;
}

MOONBIT_FFI_EXPORT
MoonBitDS4Tokens *moonbit_ds4_engine_tokenize_rendered_chat(MoonBitDS4Engine *engine, moonbit_bytes_t text) {
  MoonBitDS4Tokens *out = tokens_new_raw();
  ds4_tokenize_rendered_chat(engine->ptr, (const char *)text, &out->value);
  return out;
}

MOONBIT_FFI_EXPORT
MoonBitDS4Tokens *moonbit_ds4_engine_encode_chat_prompt(
  MoonBitDS4Engine *engine,
  moonbit_bytes_t system,
  moonbit_bytes_t prompt,
  int32_t think_mode
) {
  MoonBitDS4Tokens *out = tokens_new_raw();
  ds4_encode_chat_prompt(
    engine->ptr,
    (const char *)system,
    (const char *)prompt,
    (ds4_think_mode)think_mode,
    &out->value
  );
  return out;
}

MOONBIT_FFI_EXPORT
void moonbit_ds4_engine_chat_begin(MoonBitDS4Engine *engine, MoonBitDS4Tokens *tokens) {
  ds4_chat_begin(engine->ptr, &tokens->value);
}

MOONBIT_FFI_EXPORT
void moonbit_ds4_engine_chat_append_max_effort_prefix(MoonBitDS4Engine *engine, MoonBitDS4Tokens *tokens) {
  ds4_chat_append_max_effort_prefix(engine->ptr, &tokens->value);
}

MOONBIT_FFI_EXPORT
void moonbit_ds4_engine_chat_append_message(
  MoonBitDS4Engine *engine,
  MoonBitDS4Tokens *tokens,
  moonbit_bytes_t role,
  moonbit_bytes_t content
) {
  ds4_chat_append_message(engine->ptr, &tokens->value, (const char *)role, (const char *)content);
}

MOONBIT_FFI_EXPORT
void moonbit_ds4_engine_chat_append_assistant_prefix(
  MoonBitDS4Engine *engine,
  MoonBitDS4Tokens *tokens,
  int32_t think_mode
) {
  ds4_chat_append_assistant_prefix(engine->ptr, &tokens->value, (ds4_think_mode)think_mode);
}

MOONBIT_FFI_EXPORT
MoonBitDS4Session *moonbit_ds4_session_new(void) {
  return session_new_raw();
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_session_create(
  MoonBitDS4Session *session,
  MoonBitDS4Engine *engine,
  int32_t ctx_size
) {
  int32_t status = ds4_session_create(&session->ptr, engine->ptr, ctx_size);
  if (status == 0) {
    session->engine = engine;
    moonbit_incref(engine);
  }
  return status;
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_session_sync(
  MoonBitDS4Session *session,
  MoonBitDS4Tokens *prompt,
  uint8_t *err,
  int32_t errlen
) {
  return ds4_session_sync(session->ptr, &prompt->value, (char *)err, (size_t)errlen);
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_session_eval(
  MoonBitDS4Session *session,
  int32_t token,
  uint8_t *err,
  int32_t errlen
) {
  return ds4_session_eval(session->ptr, token, (char *)err, (size_t)errlen);
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_session_argmax(MoonBitDS4Session *session) {
  return ds4_session_argmax(session->ptr);
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_session_argmax_excluding(MoonBitDS4Session *session, int32_t excluded_id) {
  return ds4_session_argmax_excluding(session->ptr, excluded_id);
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_session_sample(
  MoonBitDS4Session *session,
  float temperature,
  int32_t top_k,
  float top_p,
  float min_p,
  MoonBitDS4Sampler *sampler
) {
  return ds4_session_sample(
    session->ptr,
    temperature,
    top_k,
    top_p,
    min_p,
    &sampler->state
  );
}

MOONBIT_FFI_EXPORT
void moonbit_ds4_session_invalidate(MoonBitDS4Session *session) {
  ds4_session_invalidate(session->ptr);
}

MOONBIT_FFI_EXPORT
void moonbit_ds4_session_rewind(MoonBitDS4Session *session, int32_t pos) {
  ds4_session_rewind(session->ptr, pos);
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_session_pos(MoonBitDS4Session *session) {
  return ds4_session_pos(session->ptr);
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_session_ctx(MoonBitDS4Session *session) {
  return ds4_session_ctx(session->ptr);
}

MOONBIT_FFI_EXPORT
MoonBitDS4Tokens *moonbit_ds4_session_tokens(MoonBitDS4Session *session) {
  MoonBitDS4Tokens *out = tokens_new_raw();
  const ds4_tokens *tokens = ds4_session_tokens(session->ptr);
  ds4_tokens_copy(&out->value, tokens);
  return out;
}
