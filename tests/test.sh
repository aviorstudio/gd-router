#!/usr/bin/env bash
set -euo pipefail

tests="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$tests/runner_contract_test.sh"

shopt -s nullglob
scripts=("$tests"/*_test.gd)
if [ "${#scripts[@]}" -eq 0 ]; then
  echo "No *_test.gd scripts were found" >&2
  exit 1
fi

for script in "${scripts[@]}"; do
  name="$(basename "$script" .gd)"
  echo "Running ${name}.gd..."
  "$tests/run_godot_test.sh" "$script" "PASS gd-router $name reachable=1"
done
