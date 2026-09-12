#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot="${GODOT_BIN:-godot}"
archive="${1:-$root/dist/@aviorstudio_gd-router.zip}"
fixtures="$root/tests/package_fixture"
tmp="$(mktemp -d)"
cleanup() {
  if [ "${KEEP_PACKAGE_FIXTURE:-0}" = 1 ]; then
    echo "Preserved package fixture: $tmp" >&2
  else
    rm -rf "$tmp"
  fi
}
trap cleanup EXIT

python3 "$root/scripts/package_addon.py" --output "$archive" --verify-only

run_editor() {
  local project="$1"
  local log="$2"
  shift 2
  set +e
  timeout --signal=TERM --kill-after=5 45 "$godot" --headless --editor --path "$project" "$@" >"$log" 2>&1
  local status=$?
  set -e
  cat "$log"
  # Godot 4.7.2's headless editor reports renderer RID cleanup errors when a
  # MainLoop automation script quits it. Keep this exact, reproduced cleanup
  # line allowlisted; all other runtime errors remain fatal.
  grep -Ev "^ERROR: [0-9]+ RID allocations? of type '.+' were leaked at exit\.$" "$log" >"$log.filtered" || true
  grep -Ev '^ERROR: [0-9]+ resources still in use at exit \(run with --verbose for details\)\.$' "$log.filtered" >"$log.filtered2" || true
  if [ "$status" -ne 0 ] || grep -Eq '(^|[[:space:]])(SCRIPT ERROR:|ERROR:|FAIL:)' "$log.filtered2"; then
    echo "packaged editor lifecycle command failed with status $status" >&2
    return 1
  fi
}

install_fixture() {
  local project="$1"
  mkdir -p "$project/addons/@aviorstudio_gd-router"
  unzip -q "$archive" -d "$project/addons/@aviorstudio_gd-router"
  cp "$fixtures/smoke.gd" "$fixtures/enable_plugin.gd" "$fixtures/disable_plugin.gd" "$project/"
}

owned="$tmp/owned"
mkdir -p "$owned"
cp "$fixtures/project.godot" "$owned/project.godot"
install_fixture "$owned"
run_editor "$owned" "$tmp/import.log" --quit-after 2
run_editor "$owned" "$tmp/enable.log" --script res://enable_plugin.gd
grep -Fqx 'PASS gd-router package_enable reachable=1' "$tmp/enable.log"
grep -Eq '^GdRouter="\*(res://addons/@aviorstudio_gd-router/autoload.gd|uid://[a-z0-9]+)"$' "$owned/project.godot"
run_editor "$owned" "$tmp/restart.log" --quit-after 2
GODOT_BIN="$godot" GODOT_PROJECT_DIR="$owned" "$root/tests/run_godot_test.sh" "$owned/smoke.gd" "PASS gd-router package_smoke reachable=1"
run_editor "$owned" "$tmp/disable.log" --script res://disable_plugin.gd
grep -Fqx 'PASS gd-router package_disable reachable=1' "$tmp/disable.log"
if grep -Fq 'autoload/GdRouter' "$owned/project.godot" || grep -Fq 'GdRouter=' "$owned/project.godot"; then
  echo "plugin-owned autoload remained after disable" >&2
  exit 1
fi
run_editor "$owned" "$tmp/disabled-restart.log" --quit-after 2

consumer="$tmp/consumer"
mkdir -p "$consumer"
cp "$fixtures/consumer_project.godot" "$consumer/project.godot"
cp "$fixtures/consumer_router.gd" "$consumer/consumer_router.gd"
install_fixture "$consumer"
run_editor "$consumer" "$tmp/consumer-import.log" --quit-after 2
run_editor "$consumer" "$tmp/consumer-enable.log" --script res://enable_plugin.gd
run_editor "$consumer" "$tmp/consumer-disable.log" --script res://disable_plugin.gd
grep -Fq 'GdRouter="*res://consumer_router.gd"' "$consumer/project.godot"
run_editor "$consumer" "$tmp/consumer-restart.log" --quit-after 2

echo "PASS gd-router package_lifecycle reachable=1 editor_restarts=4 ownership=preserved"
