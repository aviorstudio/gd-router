#!/usr/bin/env bash
set -euo pipefail

tests="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
runner="$tests/run_godot_test.sh"
fixtures="$tests/runner_fixtures"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

expect_failure() {
  local name="$1"
  shift
  if "$@" >"$tmp/$name.log" 2>&1; then
    echo "negative runner control unexpectedly passed: $name" >&2
    return 1
  fi
  echo "CONTROL_FAIL_EXPECTED $name"
}

expect_failure runtime_error "$runner" "$fixtures/runtime_error_zero_exit.gd" "PASS runner-control runtime-error"
expect_failure overwritten_failure "$runner" "$fixtures/overwritten_failure.gd" "PASS runner-control overwritten-failure"
expect_failure unreachable "$runner" "$fixtures/unreachable.gd" "PASS runner-control unreachable"
expect_failure parse_error "$runner" "$fixtures/parse_error.gd" "PASS runner-control parse-error"
expect_failure timeout env GODOT_TEST_TIMEOUT_SECONDS=1 "$runner" "$fixtures/hang.gd" "PASS runner-control hang"
expect_failure missing "$runner" "$fixtures/does-not-exist.gd" "PASS runner-control missing"

"$runner" "$fixtures/pass.gd" "PASS runner-control reachable=1 assertions=1" >"$tmp/pass.log" 2>&1
grep -Fqx "PASS runner-control reachable=1 assertions=1" "$tmp/pass.log"
echo "CONTROL_PASS_RESTORED reachable=1 assertions=1 negative_controls=6"
