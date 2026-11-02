/*
 * WASI entry point for AtomVM on Cloudflare Workers.
 *
 * Protocol: Reads the HTTP request from stdin and writes the HTTP response
 * to stdout, both in Erlang External Term Format. The CF Worker JS shim
 * handles the HTTP<->stdio bridge (see src/glowvm/internal/bridge.gleam).
 *
 * stdin:  term_to_binary({Method, Url, [{Name, Value}], Body})
 * stdout: term_to_binary({Status, [{Name, Value}], Body}), <<Size:32>>,
 *         "\n__GLOWVM__"
 *
 * Copyright 2026 elixir-workers contributors
 * SPDX-License-Identifier: Apache-2.0
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <avm_version.h>
#include <avmpack.h>
#include <context.h>
#include <defaultatoms.h>
#include <globalcontext.h>
#include <iff.h>
#include <module.h>
#include <sys.h>

#include "platform_defaultatoms.h"
#include "wasi_sys.h"

static GlobalContext *global = NULL;
static Module *main_module = NULL;

/**
 * Load a module in .avm or .beam format from the WASI virtual filesystem.
 */
static int load_module(const char *path)
{
    const char *ext = strrchr(path, '.');
    if (ext && strcmp(ext, ".avm") == 0) {
        struct AVMPackData *avmpack_data;
        if (sys_open_avm_from_file(global, path, &avmpack_data) != AVM_OPEN_OK) {
            fprintf(stderr, "[atomvm-wasi] Failed opening %s\n", path);
            return EXIT_FAILURE;
        }
        synclist_append(&global->avmpack_data, &avmpack_data->avmpack_head);

        if (main_module == NULL) {
            const void *startup_beam = NULL;
            uint32_t startup_beam_size;
            const char *startup_module_name;
            avmpack_find_section_by_flag(
                avmpack_data->data, BEAM_START_FLAG, BEAM_START_FLAG,
                &startup_beam, &startup_beam_size, &startup_module_name);

            if (startup_beam) {
                avmpack_data->in_use = true;
                main_module = module_new_from_iff_binary(global, startup_beam, startup_beam_size);
                if (main_module == NULL) {
                    fprintf(stderr, "[atomvm-wasi] Cannot load startup module: %s\n",
                        startup_module_name);
                    return EXIT_FAILURE;
                }
                globalcontext_insert_module(global, main_module);
                main_module->module_platform_data = NULL;
            }
        }
    } else if (ext && strcmp(ext, ".beam") == 0) {
        Module *module = sys_load_module_from_file(global, path);
        if (module == NULL) {
            fprintf(stderr, "[atomvm-wasi] Failed loading %s\n", path);
            return EXIT_FAILURE;
        }
        globalcontext_insert_module(global, module);
        if (main_module == NULL
            && module_search_exported_function(module, START_ATOM_INDEX, 0) != 0) {
            main_module = module;
        }
    } else {
        fprintf(stderr, "[atomvm-wasi] %s is not an AVM or BEAM file.\n", path);
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}

/**
 * WASI entry point.
 *
 * Usage: atomvm <file.avm|file.beam> [additional.avm ...]
 *
 * The first .avm file's start module (or first .beam with start/0)
 * becomes the main module. The main module's start/0 function should:
 * 1. Read the HTTP request from stdin
 * 2. Process the request
 * 3. Write the HTTP response to stdout
 * 4. Return
 */
int main(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stderr,
            "[atomvm-wasi] Usage: atomvm <file.avm> [additional.avm ...]\n"
            "  BEAM VM for Cloudflare Workers\n");
        return EXIT_FAILURE;
    }

    int result = EXIT_SUCCESS;

    global = globalcontext_new();
    if (global == NULL) {
        fprintf(stderr, "[atomvm-wasi] Failed to create global context\n");
        return EXIT_FAILURE;
    }

    /* Load all specified modules */
    for (int i = 1; i < argc; ++i) {
        result = load_module(argv[i]);
        if (result != EXIT_SUCCESS) {
            break;
        }
    }

    /* Run the main module */
    if (result == EXIT_SUCCESS) {
        if (main_module == NULL) {
            fprintf(stderr, "[atomvm-wasi] No main module found\n");
            result = EXIT_FAILURE;
        } else {
            run_result_t ret = globalcontext_run(global, main_module, stdout, 0, NULL);
            if (ret != RUN_SUCCESS) {
                result = EXIT_FAILURE;
            }
        }
    }

    globalcontext_destroy(global);
    global = NULL;
    main_module = NULL;

    return result;
}
