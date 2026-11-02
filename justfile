default:
    @just --list

build:
    ./scripts/build-glowvm.sh

test:
    gleam build
    erl -noshell -pa build/dev/erlang/glowvm/ebin -eval 'halt(0).'
    cd fixtures/app && gleam run -m build_all
    bun test scripts/smoke.test.ts
    ./scripts/check-no-dupe-beams.sh

minify-entry:
    bunx uglify-js priv/index.js --v8 -o priv/index.min.js

publish-hex:
    gleam build
    printf 'I am not using semantic versioning\n' | gleam publish --yes
