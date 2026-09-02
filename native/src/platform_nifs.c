/*
 * WASI platform NIFs — minimal set for HTTP request/response handling.
 * These NIFs allow Elixir code to interact with stdin/stdout for the
 * HTTP bridge protocol.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <atom.h>
#include <defaultatoms.h>
#include <erl_nif.h>
#include <erl_nif_priv.h>
#include <globalcontext.h>
#include <interop.h>
#include <memory.h>
#include <nifs.h>
#include <term.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/random.h>

#include "platform_defaultatoms.h"
#include "wasi_sys.h"

/**
 * Returns the platform atom `:wasi`
 */
static term nif_atomvm_platform(Context *ctx, int argc, term argv[]) {
  (void)ctx;
  (void)argc;
  (void)argv;
  return WASI_ATOM;
}

static term nif_wasi_read_stdin(Context *ctx, int argc, term argv[]) {
  (void)argc;
  (void)argv;

  const size_t MAX_INPUT_SIZE = 10 * 1024 * 1024;
  size_t capacity = 4096;
  size_t len = 0;
  char *buf = malloc(capacity);
  if (!buf) {
    RAISE_ERROR(OUT_OF_MEMORY_ATOM);
  }

  while (1) {
    size_t n = fread(buf + len, 1, capacity - len, stdin);
    len += n;
    if (n == 0 || feof(stdin)) {
      break;
    }
    if (len == capacity) {
      if (capacity * 2 > MAX_INPUT_SIZE) {
        free(buf);
        RAISE_ERROR(OUT_OF_MEMORY_ATOM);
      }
      size_t new_capacity = capacity * 2;
      char *newbuf = realloc(buf, new_capacity);
      if (!newbuf) {
        free(buf);
        RAISE_ERROR(OUT_OF_MEMORY_ATOM);
      }
      buf = newbuf;
      capacity = new_capacity;
    }
  }

  if (UNLIKELY(memory_ensure_free(ctx, term_binary_heap_size(len)) !=
               MEMORY_GC_OK)) {
    free(buf);
    RAISE_ERROR(OUT_OF_MEMORY_ATOM);
  }

  term result = term_from_literal_binary(buf, len, &ctx->heap, ctx->global);
  free(buf);
  return result;
}

static term nif_wasi_write_stdout(Context *ctx, int argc, term argv[]) {
  (void)argc;

  term data = argv[0];
  if (!term_is_binary(data)) {
    RAISE_ERROR(BADARG_ATOM);
  }

  const char *bytes = term_binary_data(data);
  size_t len = term_binary_size(data);

  size_t written = fwrite(bytes, 1, len, stdout);
  fflush(stdout);

  if (written != len) {
    return ERROR_ATOM;
  }

  return OK_ATOM;
}

static term nif_crypto_strong_rand_bytes(Context *ctx, int argc, term argv[]) {
  (void)argc;

  if (!term_is_integer(argv[0])) {
    RAISE_ERROR(BADARG_ATOM);
  }
  avm_int_t n = term_to_int(argv[0]);
  if (n < 0) {
    RAISE_ERROR(BADARG_ATOM);
  }

  if (UNLIKELY(memory_ensure_free(ctx, term_binary_heap_size(n)) !=
               MEMORY_GC_OK)) {
    RAISE_ERROR(OUT_OF_MEMORY_ATOM);
  }

  term result = term_create_uninitialized_binary(n, &ctx->heap, ctx->global);
  char *buf = (char *)term_binary_data(result);
  /* getentropy caps out at 256 bytes per call */
  for (avm_int_t off = 0; off < n; off += 256) {
    size_t chunk = (size_t)((n - off) < 256 ? (n - off) : 256);
    if (getentropy(buf + off, chunk) != 0) {
      RAISE_ERROR(BADARG_ATOM);
    }
  }

  return result;
}

/**
 * `directories:tmp_dir/0` (via wisp -> make_connection) calls
 * `platform:os/0` -> `os:type/0`, which AtomVM doesn't provide. Report
 * `{unix, linux}`, same as OTP's real os:type/0 would on any WASI host.
 * There's no real filesystem for the caller to probe afterwards anyway
 * (WASI's virtual FS only has app.avm), so tmp_dir/0 fails its directory
 * checks and wisp falls back to its own "./tmp/" default either way.
 */
static term nif_os_type(Context *ctx, int argc, term argv[]) {
  (void)argc;
  (void)argv;

  if (UNLIKELY(memory_ensure_free(ctx, TUPLE_SIZE(2)) != MEMORY_GC_OK)) {
    RAISE_ERROR(OUT_OF_MEMORY_ATOM);
  }

  term result = term_alloc_tuple(2, &ctx->heap);
  term_put_tuple_element(
      result, 0,
      globalcontext_make_atom(ctx->global, ATOM_STR("\x4", "unix")));
  term_put_tuple_element(
      result, 1,
      globalcontext_make_atom(ctx->global, ATOM_STR("\x5", "linux")));
  return result;
}

/* NIF table */
static const struct Nif atomvm_platform_nif = {.base.type = NIFFunctionType,
                                               .nif_ptr = nif_atomvm_platform};

static const struct Nif wasi_read_stdin_nif = {.base.type = NIFFunctionType,
                                               .nif_ptr = nif_wasi_read_stdin};

static const struct Nif wasi_write_stdout_nif = {
    .base.type = NIFFunctionType, .nif_ptr = nif_wasi_write_stdout};

static const struct Nif crypto_strong_rand_bytes_nif = {
    .base.type = NIFFunctionType, .nif_ptr = nif_crypto_strong_rand_bytes};

static const struct Nif os_type_nif = {.base.type = NIFFunctionType,
                                       .nif_ptr = nif_os_type};

const struct Nif *platform_nifs_get_nif(const char *nifname) {
  if (strcmp("atomvm:platform/0", nifname) == 0) {
    return &atomvm_platform_nif;
  }
  if (strcmp("host_io:read_stdin/0", nifname) == 0) {
    return &wasi_read_stdin_nif;
  }
  if (strcmp("host_io:write_stdout/1", nifname) == 0) {
    return &wasi_write_stdout_nif;
  }
  if (strcmp("crypto:strong_rand_bytes/1", nifname) == 0) {
    return &crypto_strong_rand_bytes_nif;
  }
  if (strcmp("os:type/0", nifname) == 0) {
    return &os_type_nif;
  }
  return NULL;
}
