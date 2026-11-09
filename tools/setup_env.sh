#!/usr/bin/env bash
# Prepares a fresh clone so the checks and exports in docs/DEVELOPMENT.md can run.
#
#   tools/setup_env.sh                      install the pinned Godot and import the project
#   tools/setup_env.sh --templates web      also install the Web export templates
#   tools/setup_env.sh --templates android  also install the Android export templates
#   tools/setup_env.sh --templates all      both (one 1.3 GB download either way)
#   tools/setup_env.sh --skip-import        do not build the .godot import cache
#   tools/setup_env.sh --check              install nothing; report what is ready and what is missing
#
# This is the single source of truth for environment setup. It is agent-neutral: call it from a
# Codex or Claude cloud-environment setup script, a CI step, or by hand. Do not copy its logic into
# an agent-specific setting; call it, so the Godot version and the install steps stay in the
# repository next to `.godot-version`.
#
# Safe to run again: whatever is already installed is skipped, and downloads are verified against
# the SHA-512 sums published with the Godot release. It runs from any directory.
#
# Environment:
#   INITIALSJ_GODOT_BIN   use this Godot executable instead of installing one (as tools/godot does)
#   XDG_DATA_HOME         export templates go to $XDG_DATA_HOME/godot (default ~/.local/share/godot)
#
# Network: github.com and release-assets.githubusercontent.com (Godot release downloads).
# Android APK builds additionally need a JDK and the Android SDK, which tools/build_android.sh sets up.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

version="$(tr -d '[:space:]' < .godot-version)"
release="https://github.com/godotengine/godot/releases/download/$version-stable"
engine_dir="$HOME/.local/share/godot/engines/$version"
engine_bin="$engine_dir/Godot_v$version-stable_linux.x86_64"
templates_dir="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$version.stable"

check_only=0
skip_import=0
want_web=0
want_android=0

usage() { sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }
log() { printf '[setup_env] %s\n' "$*"; }
fail() { printf '[setup_env] ERROR: %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) check_only=1 ;;
    --skip-import) skip_import=1 ;;
    --templates)
      [[ $# -ge 2 ]] || fail "--templates needs web, android or all"
      case "$2" in
        web) want_web=1 ;;
        android) want_android=1 ;;
        all) want_web=1; want_android=1 ;;
        *) fail "--templates needs web, android or all (got '$2')" ;;
      esac
      shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option '$1' (try --help)" ;;
  esac
  shift
done

work=""
cleanup() { if [[ -n "$work" ]]; then rm -rf "$work"; fi; }
trap cleanup EXIT

engine_ready() { ./tools/godot --version > /dev/null 2>&1; }
web_ready() { [[ -f "$templates_dir/version.txt" && -f "$templates_dir/web_release.zip" && -f "$templates_dir/web_nothreads_release.zip" ]]; }
android_ready() { [[ -f "$templates_dir/version.txt" && -f "$templates_dir/android_debug.apk" && -f "$templates_dir/android_release.apk" ]]; }

# --- check mode: report only -------------------------------------------------------------------
if [[ $check_only -eq 1 ]]; then
  status=0
  if engine_ready; then log "Godot $version: ready ($(./tools/godot --version))"; else log "Godot $version: MISSING (run tools/setup_env.sh)"; status=1; fi
  for tool in python3 node; do
    if command -v "$tool" > /dev/null; then log "$tool: $(command -v "$tool")"; else log "$tool: MISSING (needed by the checks in docs/DEVELOPMENT.md)"; status=1; fi
  done
  if web_ready; then log "Web export templates: ready"; else log "Web export templates: not installed (only needed to export the Web build; --templates web)"; fi
  if android_ready; then log "Android export templates: ready"; else log "Android export templates: not installed (tools/build_android.sh installs them; --templates android)"; fi
  exit $status
fi

# --- prerequisites -----------------------------------------------------------------------------
missing=()
for tool in curl unzip sha512sum; do
  command -v "$tool" > /dev/null || missing+=("$tool")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  fail "missing tools: ${missing[*]}. On Debian/Ubuntu: apt-get install -y curl unzip coreutils"
fi
for tool in python3 node; do
  command -v "$tool" > /dev/null || log "warning: $tool is not installed; the checks in docs/DEVELOPMENT.md need it"
done

fetch() { curl -fL --retry 4 --retry-delay 3 --retry-connrefused -sS -o "$2" "$1"; }

# Verifies $1 (a file in the working directory $work) against the release's SHA512-SUMS.txt.
verify_download() {
  local name="$1" expected actual
  expected="$(awk -v n="$name" '$2 == n || $2 == "*" n {print $1; exit}' "$work/SHA512-SUMS.txt")"
  [[ -n "$expected" ]] || fail "$name is not listed in the release's SHA512-SUMS.txt"
  actual="$(sha512sum "$work/$name" | cut -d' ' -f1)"
  [[ "$expected" == "$actual" ]] || fail "SHA-512 mismatch for $name (expected $expected, got $actual)"
}

ensure_work() {
  if [[ -z "$work" ]]; then
    work="$(mktemp -d)"
    log "Fetching SHA512-SUMS.txt for Godot $version ..."
    fetch "$release/SHA512-SUMS.txt" "$work/SHA512-SUMS.txt"
  fi
}

# --- Godot engine ------------------------------------------------------------------------------
if engine_ready; then
  log "Godot $version already available ($(./tools/godot --version))."
elif [[ -n "${INITIALSJ_GODOT_BIN:-}" ]]; then
  fail "INITIALSJ_GODOT_BIN=$INITIALSJ_GODOT_BIN is not a Godot $version stable executable. Fix or unset it."
else
  [[ "$(uname -s)-$(uname -m)" == "Linux-x86_64" ]] || fail "automatic install supports Linux x86_64 only. Install Godot $version stable yourself and set INITIALSJ_GODOT_BIN."
  zip_name="Godot_v$version-stable_linux.x86_64.zip"
  ensure_work
  log "Downloading Godot $version (about 78 MB) ..."
  fetch "$release/$zip_name" "$work/$zip_name"
  verify_download "$zip_name"
  mkdir -p "$(dirname "$engine_dir")"
  staging="$(mktemp -d "$(dirname "$engine_dir")/.install-XXXXXX")"
  unzip -q -o "$work/$zip_name" -d "$staging"
  [[ -f "$staging/Godot_v$version-stable_linux.x86_64" ]] || { rm -rf "$staging"; fail "the Godot archive does not contain Godot_v$version-stable_linux.x86_64"; }
  chmod +x "$staging/Godot_v$version-stable_linux.x86_64"
  rm -rf "$engine_dir"
  mv "$staging" "$engine_dir"
  log "Installed $engine_bin"
fi
engine_ready || fail "Godot is installed but does not run as Godot $version stable. Run ./tools/godot --version to see why (a missing system library is the usual cause)."

# --- export templates (optional) ---------------------------------------------------------------
need_web=0
need_android=0
[[ $want_web -eq 1 ]] && ! web_ready && need_web=1
[[ $want_android -eq 1 ]] && ! android_ready && need_android=1
if [[ $need_web -eq 1 || $need_android -eq 1 ]]; then
  tpz="Godot_v$version-stable_export_templates.tpz"
  ensure_work
  log "Downloading the export templates (about 1.3 GB) ..."
  fetch "$release/$tpz" "$work/$tpz"
  verify_download "$tpz"
  mkdir -p "$templates_dir"
  patterns=("templates/version.txt")
  [[ $need_web -eq 1 ]] && patterns+=("templates/web*")
  [[ $need_android -eq 1 ]] && patterns+=("templates/android*")
  unzip -q -o "$work/$tpz" "${patterns[@]}" -d "$work/extracted"
  cp "$work"/extracted/templates/* "$templates_dir/"
  log "Installed export templates into $templates_dir"
fi
if [[ $want_web -eq 1 ]]; then web_ready || fail "the Web export templates are incomplete in $templates_dir"; fi
if [[ $want_android -eq 1 ]]; then android_ready || fail "the Android export templates are incomplete in $templates_dir"; fi

# --- project import ----------------------------------------------------------------------------
if [[ $skip_import -eq 0 ]]; then
  log "Importing the project (builds the ignored .godot cache) ..."
  ./tools/godot --headless --path . --editor --import --quit > /dev/null 2>&1 || fail "project import failed. Run ./tools/godot --headless --path . --editor --import --quit to see why."
fi
./tools/godot --headless --path . --script res://tests/verify_engine.gd 2>&1 | sed -e '/^$/d' -e 's/^/[setup_env] /'
[[ "${PIPESTATUS[0]}" -eq 0 ]] || fail "the engine version check failed"

log "Ready. Next: python3 tools/verify_repository.py  and the checks in docs/DEVELOPMENT.md"
