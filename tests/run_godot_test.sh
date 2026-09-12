#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 SCRIPT EXPECTED_PASS_SENTINEL" >&2
  exit 2
fi

default_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
root="${GODOT_PROJECT_DIR:-$default_root}"
godot="${GODOT_BIN:-godot}"
script="$1"
sentinel="$2"
timeout_seconds="${GODOT_TEST_TIMEOUT_SECONDS:-45}"
log="$(mktemp)"
trap 'rm -f "$log"' EXIT

if [ ! -f "$script" ]; then
  echo "Missing Godot test script: $script" >&2
  exit 1
fi

set +e
timeout --signal=TERM --kill-after=5 "$timeout_seconds" \
  "$godot" --headless --path "$root" --script "$script" >"$log" 2>&1
status=$?
set -e
cat "$log"

if [ "$status" -eq 124 ] || [ "$status" -eq 137 ]; then
  echo "Godot test timed out after ${timeout_seconds}s: $script" >&2
  exit 1
fi
if [ "$status" -ne 0 ]; then
  echo "Godot test exited with status $status: $script" >&2
  exit 1
fi
if grep -Eq '(^|[[:space:]])(SCRIPT ERROR:|ERROR:|FAIL:)' "$log"; then
  echo "Godot test emitted an unexpected runtime error: $script" >&2
  exit 1
fi
count="$(grep -Fxc "$sentinel" "$log" || true)"
if [ "$count" -ne 1 ]; then
  echo "Expected exactly one reachable assertion sentinel '$sentinel'; found $count" >&2
  exit 1
fi
