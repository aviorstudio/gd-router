#!/usr/bin/env bash
set -euo pipefail
export RUNNER_TEMP="${RUNNER_TEMP:-$PWD/.artifacts/tmp}"
mkdir -p "$RUNNER_TEMP"
./scripts/package_addon.py
