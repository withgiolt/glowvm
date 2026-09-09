#!/usr/bin/env bash
# Every app.avm should list each module once. A duplicate is exactly the
# symptom of the priv/ leak fixed in src/glowvm/build.gleam — see
# is_under_priv there.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

fail=0
for avm in "${PROJECT_DIR}"/fixtures/app/dist/*/app.avm; do
  dupes="$(strings -a "$avm" | grep -E '^[a-zA-Z_0-9@]+\.beam$' | sort | uniq -d)"
  if [[ -n "$dupes" ]]; then
    echo "duplicate modules in $avm:" >&2
    echo "$dupes" >&2
    fail=1
  fi
done

if [[ "$fail" -eq 0 ]]; then
  echo "no duplicate modules in any app.avm"
fi
exit "$fail"
