default:
    @just --list

build:
    ./scripts/build-glowvm.sh

test:
    cd fixtures/app && gleam run -m build_all
    deno run -A scripts/gen_importmap.ts
    deno test -A --import-map=fixtures/app/dist/importmap.json scripts/smoke.test.ts

minify-entry:
    deno run -REW npm:uglify-js priv/index.js --v8 -o priv/index.min.js
