default:
    @just --list

build:
    ./scripts/build-atomvm.sh

test:
    cd fixtures/smoke_app && gleam run -m build_all
    deno task smoke
