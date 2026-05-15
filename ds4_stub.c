#include "moonbit.h"
#include "ds4.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  ds4_engine *ptr;
  int32_t status;
} MoonBitDS4Engine;

typedef struct {
  ds4_session *ptr;
  MoonBitDS4Engine *engine;
  int32_t status;
  char last_error[1024];
} MoonBitDS4Session;

typedef struct {
  ds4_tokens value;
} MoonBitDS4Tokens;

static const char *mb_cstr(moonbit_bytes_t bytes) {
  return bytes ? (const char *)bytes : "";
}

static moonbit_bytes_t mb_copy_bytes(const char *ptr, size_t len) {
  moonbit_bytes_t out = moonbit_make_bytes((int32_t)len, 0);
  if (len > 0) {
    memcpy(out, ptr, len);
  }
  return out;
}

static moonbit_bytes_t mb_copy_cstr(const char *ptr) {
  if (!ptr) {
    ptr = "";
  }
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

static MoonBitDS4Engine *engine_new_raw(void) {
  MoonBitDS4Engine *engine = (MoonBitDS4Engine *)moonbit_make_external_object(
    engine_finalize,
    sizeof(MoonBitDS4Engine)
  );
  engine->ptr = NULL;
  engine->status = 1;
  return engine;
}

static MoonBitDS4Session *session_new_raw(void) {
  MoonBitDS4Session *session = (MoonBitDS4Session *)moonbit_make_external_object(
    session_finalize,
    sizeof(MoonBitDS4Session)
  );
  session->ptr = NULL;
  session->engine = NULL;
  session->status = 1;
  session->last_error[0] = '\0';
  return session;
}

static void session_set_error(MoonBitDS4Session *session, const char *message) {
  if (!message) {
    message = "";
  }
  snprintf(session->last_error, sizeof(session->last_error), "%s", message);
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
MoonBitDS4Engine *moonbit_ds4_engine_open(
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
  int32_t quality
) {
  MoonBitDS4Engine *engine = engine_new_raw();
  ds4_engine_options opt = {0};
  opt.model_path = mb_cstr(model_path);
  opt.mtp_path = mb_cstr(mtp_path);
  opt.backend = (ds4_backend)backend;
  opt.n_threads = n_threads;
  opt.mtp_draft_tokens = mtp_draft_tokens;
  opt.mtp_margin = mtp_margin;
  opt.directional_steering_file = mb_cstr(directional_steering_file);
  opt.directional_steering_attn = directional_steering_attn;
  opt.directional_steering_ffn = directional_steering_ffn;
  opt.warm_weights = warm_weights != 0;
  opt.quality = quality != 0;
  engine->status = ds4_engine_open(&engine->ptr, &opt);
  return engine;
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_engine_status(MoonBitDS4Engine *engine) {
  return engine ? engine->status : 1;
}

MOONBIT_FFI_EXPORT
void moonbit_ds4_engine_summary(MoonBitDS4Engine *engine) {
  if (engine && engine->ptr) {
    ds4_engine_summary(engine->ptr);
  }
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_engine_token_eos(MoonBitDS4Engine *engine) {
  return engine && engine->ptr ? ds4_token_eos(engine->ptr) : -1;
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_engine_routed_quant_bits(MoonBitDS4Engine *engine) {
  return engine && engine->ptr ? ds4_engine_routed_quant_bits(engine->ptr) : 0;
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_engine_has_mtp(MoonBitDS4Engine *engine) {
  return (int32_t)(engine && engine->ptr && ds4_engine_has_mtp(engine->ptr));
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_engine_mtp_draft_tokens(MoonBitDS4Engine *engine) {
  return engine && engine->ptr ? ds4_engine_mtp_draft_tokens(engine->ptr) : 0;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moonbit_ds4_engine_token_text(MoonBitDS4Engine *engine, int32_t token) {
  if (!engine || !engine->ptr) {
    return mb_copy_cstr("");
  }
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
MoonBitDS4Tokens *moonbit_ds4_tokens_copy(MoonBitDS4Tokens *tokens) {
  MoonBitDS4Tokens *out = tokens_new_raw();
  if (tokens) {
    ds4_tokens_copy(&out->value, &tokens->value);
  }
  return out;
}

MOONBIT_FFI_EXPORT
void moonbit_ds4_tokens_push(MoonBitDS4Tokens *tokens, int32_t token) {
  if (tokens) {
    ds4_tokens_push(&tokens->value, token);
  }
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_tokens_length(MoonBitDS4Tokens *tokens) {
  return tokens ? tokens->value.len : 0;
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_tokens_get(MoonBitDS4Tokens *tokens, int32_t index) {
  if (!tokens || index < 0 || index >= tokens->value.len) {
    return 0;
  }
  return tokens->value.v[index];
}

MOONBIT_FFI_EXPORT
int32_t *moonbit_ds4_tokens_to_fixed_array(MoonBitDS4Tokens *tokens) {
  int32_t len = tokens ? tokens->value.len : 0;
  int32_t *out = moonbit_make_int32_array_raw(len);
  for (int32_t i = 0; i < len; i++) {
    out[i] = tokens->value.v[i];
  }
  return out;
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_tokens_starts_with(MoonBitDS4Tokens *tokens, MoonBitDS4Tokens *prefix) {
  if (!tokens || !prefix) {
    return 0;
  }
  return (int32_t)ds4_tokens_starts_with(&tokens->value, &prefix->value);
}

MOONBIT_FFI_EXPORT
MoonBitDS4Tokens *moonbit_ds4_engine_tokenize_text(MoonBitDS4Engine *engine, moonbit_bytes_t text) {
  MoonBitDS4Tokens *out = tokens_new_raw();
  if (engine && engine->ptr) {
    ds4_tokenize_text(engine->ptr, mb_cstr(text), &out->value);
  }
  return out;
}

MOONBIT_FFI_EXPORT
MoonBitDS4Tokens *moonbit_ds4_engine_tokenize_rendered_chat(MoonBitDS4Engine *engine, moonbit_bytes_t text) {
  MoonBitDS4Tokens *out = tokens_new_raw();
  if (engine && engine->ptr) {
    ds4_tokenize_rendered_chat(engine->ptr, mb_cstr(text), &out->value);
  }
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
  if (engine && engine->ptr) {
    ds4_encode_chat_prompt(
      engine->ptr,
      mb_cstr(system),
      mb_cstr(prompt),
      (ds4_think_mode)think_mode,
      &out->value
    );
  }
  return out;
}

MOONBIT_FFI_EXPORT
void moonbit_ds4_engine_chat_begin(MoonBitDS4Engine *engine, MoonBitDS4Tokens *tokens) {
  if (engine && engine->ptr && tokens) {
    ds4_chat_begin(engine->ptr, &tokens->value);
  }
}

MOONBIT_FFI_EXPORT
void moonbit_ds4_engine_chat_append_max_effort_prefix(MoonBitDS4Engine *engine, MoonBitDS4Tokens *tokens) {
  if (engine && engine->ptr && tokens) {
    ds4_chat_append_max_effort_prefix(engine->ptr, &tokens->value);
  }
}

MOONBIT_FFI_EXPORT
void moonbit_ds4_engine_chat_append_message(
  MoonBitDS4Engine *engine,
  MoonBitDS4Tokens *tokens,
  moonbit_bytes_t role,
  moonbit_bytes_t content
) {
  if (engine && engine->ptr && tokens) {
    ds4_chat_append_message(engine->ptr, &tokens->value, mb_cstr(role), mb_cstr(content));
  }
}

MOONBIT_FFI_EXPORT
void moonbit_ds4_engine_chat_append_assistant_prefix(
  MoonBitDS4Engine *engine,
  MoonBitDS4Tokens *tokens,
  int32_t think_mode
) {
  if (engine && engine->ptr && tokens) {
    ds4_chat_append_assistant_prefix(engine->ptr, &tokens->value, (ds4_think_mode)think_mode);
  }
}

MOONBIT_FFI_EXPORT
MoonBitDS4Session *moonbit_ds4_session_create(MoonBitDS4Engine *engine, int32_t ctx_size) {
  MoonBitDS4Session *session = session_new_raw();
  if (!engine || !engine->ptr) {
    session_set_error(session, "engine is not open");
    return session;
  }
  session->status = ds4_session_create(&session->ptr, engine->ptr, ctx_size);
  if (session->status == 0) {
    session->engine = engine;
    moonbit_incref(engine);
  } else {
    session_set_error(session, "ds4_session_create failed");
  }
  return session;
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_session_status(MoonBitDS4Session *session) {
  return session ? session->status : 1;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moonbit_ds4_session_last_error(MoonBitDS4Session *session) {
  return mb_copy_cstr(session ? session->last_error : "session is null");
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_session_sync(MoonBitDS4Session *session, MoonBitDS4Tokens *prompt) {
  if (!session || !session->ptr || !prompt) {
    if (session) {
      session_set_error(session, "session or prompt is null");
    }
    return 1;
  }
  char err[1024] = {0};
  int32_t status = ds4_session_sync(session->ptr, &prompt->value, err, sizeof(err));
  session_set_error(session, err);
  return status;
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_session_eval(MoonBitDS4Session *session, int32_t token) {
  if (!session || !session->ptr) {
    if (session) {
      session_set_error(session, "session is null");
    }
    return 1;
  }
  char err[1024] = {0};
  int32_t status = ds4_session_eval(session->ptr, token, err, sizeof(err));
  session_set_error(session, err);
  return status;
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_session_argmax(MoonBitDS4Session *session) {
  return session && session->ptr ? ds4_session_argmax(session->ptr) : -1;
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_session_argmax_excluding(MoonBitDS4Session *session, int32_t excluded_id) {
  return session && session->ptr ? ds4_session_argmax_excluding(session->ptr, excluded_id) : -1;
}

MOONBIT_FFI_EXPORT
void moonbit_ds4_session_invalidate(MoonBitDS4Session *session) {
  if (session && session->ptr) {
    ds4_session_invalidate(session->ptr);
  }
}

MOONBIT_FFI_EXPORT
void moonbit_ds4_session_rewind(MoonBitDS4Session *session, int32_t pos) {
  if (session && session->ptr) {
    ds4_session_rewind(session->ptr, pos);
  }
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_session_pos(MoonBitDS4Session *session) {
  return session && session->ptr ? ds4_session_pos(session->ptr) : 0;
}

MOONBIT_FFI_EXPORT
int32_t moonbit_ds4_session_ctx(MoonBitDS4Session *session) {
  return session && session->ptr ? ds4_session_ctx(session->ptr) : 0;
}

MOONBIT_FFI_EXPORT
MoonBitDS4Tokens *moonbit_ds4_session_tokens(MoonBitDS4Session *session) {
  MoonBitDS4Tokens *out = tokens_new_raw();
  if (session && session->ptr) {
    const ds4_tokens *tokens = ds4_session_tokens(session->ptr);
    if (tokens) {
      ds4_tokens_copy(&out->value, tokens);
    }
  }
  return out;
}
