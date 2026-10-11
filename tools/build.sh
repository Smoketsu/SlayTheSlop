#!/usr/bin/env bash
# Exports the playtest builds (Windows, macOS, Linux) into build/ with the pinned Godot (task 051).
# Lane: tools (Agent B). The presets it exports live in export_presets.cfg (a shared contract);
# this script reads their names and output paths from there, so it never needs a second list.
#
# Usage: tools/build.sh                    # installs export templates if missing, exports every
#                                          # preset into build/
#        tools/build.sh --check            # the same, then runs the Linux build headless as a
#                                          # smoke test
#        tools/build.sh [--check] PRESET.. # only the named presets, for example
#                                          # tools/build.sh --check Linux "Windows Desktop"
#        tools/build.sh --help             # prints this usage
#
# Exit code 0 when every export (and the smoke test, with --check) succeeded, 1 otherwise, 2 for a
# bad command line. Not run in CI: the first run downloads about 1 GB of templates (2 GB unpacked)
# and each run takes a minute or so (task 051, "do not export in CI unless both people agree").
#
# Environment it reads (none of these are set by this project):
#   HOME, XDG_DATA_HOME  where Godot keeps export templates on Linux, see TEMPLATES_DIR below.
set -euo pipefail

# GODOT_VERSION: the pinned Godot release, without "-stable". Must equal GODOT_VERSION in
# tools/install_godot.sh; change both in the same small PR (a shared-contract change).
GODOT_VERSION="4.7.2"
# TEMPLATES_TAG: the folder name Godot gives this version's templates, and the exact text of the
# archive's templates/version.txt. Derived from GODOT_VERSION; do not edit.
TEMPLATES_TAG="${GODOT_VERSION}.stable"
# TEMPLATES_FILE: the official export templates archive (.tpz is a zip) of the pinned release.
TEMPLATES_FILE="Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
# TEMPLATES_URL: where TEMPLATES_FILE is downloaded from: the official GitHub release.
TEMPLATES_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/$TEMPLATES_FILE"
# TEMPLATES_SHA512: TEMPLATES_FILE's SHA-512, copied from that release's SHA512-SUMS.txt. Changes
# only together with GODOT_VERSION.
TEMPLATES_SHA512="ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079"
# QUIT_AFTER_FRAMES: how many main-loop iterations the --check smoke run lasts before Godot quits
# on its own (Godot's --quit-after). Long enough for the main scene to load data/ and build the
# ruleset; headless frames take milliseconds. Range 1 or more; tools lane may tune it.
QUIT_AFTER_FRAMES=300
# CHECK_TIMEOUT_SECONDS: the smoke run is killed and fails if it is still running after this many
# seconds (a hang). Tools lane may tune it.
CHECK_TIMEOUT_SECONDS=120
# REPO_ROOT: the repository root, found from this script's own location.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# PRESETS_FILE: the export presets this script builds (shared contract).
PRESETS_FILE="$REPO_ROOT/export_presets.cfg"
# BUILD_DIR: where every export lands. Git-ignored; holds a .gdignore so Godot never imports it.
BUILD_DIR="$REPO_ROOT/build"

# check: 1 when --check was given (run the Linux smoke test after exporting), else 0.
check=0
# wanted: the preset names given on the command line; empty means every preset in PRESETS_FILE.
wanted=()
# arg: one command-line argument.
for arg in "$@"; do
  case "$arg" in
    --check) check=1 ;;
    -h|--help) sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "build.sh: unknown option '$arg' (try --help)." >&2; exit 2 ;;
    *) wanted+=("$arg") ;;
  esac
done

# TEMPLATES_DIR: where Godot looks for this version's export templates. It cannot be pointed
# elsewhere (only Godot's "self-contained mode" moves it, and that would also move user:// for
# tools/test.sh), so the templates go where Godot's own template manager would put them.
case "$(uname -s)" in
  Linux) TEMPLATES_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$TEMPLATES_TAG" ;;
  Darwin) TEMPLATES_DIR="$HOME/Library/Application Support/Godot/export_templates/$TEMPLATES_TAG" ;;
  *)
    echo "build.sh: runs on Linux and macOS only (on Windows, use WSL)." >&2
    exit 1 ;;
esac

# GODOT: the pinned Godot binary (the editor build, which can export), installed on first use.
GODOT="$("$REPO_ROOT/tools/install_godot.sh")"

# sha512_of FILE: prints FILE's SHA-512 in hex, with sha512sum (Linux) or shasum (macOS).
sha512_of() {
  if command -v sha512sum >/dev/null; then
    sha512sum "$1" | cut -d' ' -f1
  else
    shasum -a 512 "$1" | cut -d' ' -f1
  fi
}

# install_templates: makes sure TEMPLATES_DIR holds the pinned templates. Downloads the archive,
# refuses it unless its SHA-512 is TEMPLATES_SHA512, unpacks it next to TEMPLATES_DIR and moves it
# into place in one step, so an interrupted run never leaves a half-filled templates folder.
install_templates() {
  if [[ -f "$TEMPLATES_DIR/version.txt" ]] \
      && [[ "$(tr -d '[:space:]' < "$TEMPLATES_DIR/version.txt")" == "$TEMPLATES_TAG" ]]; then
    return 0
  fi
  # parent: the export_templates/ folder that holds TEMPLATES_DIR.
  # tmp: scratch folder for the download and the unpacked archive, removed on exit. It sits next
  # to TEMPLATES_DIR (same disk) so the final mv is a rename, not a 2 GB copy.
  # actual: the downloaded archive's SHA-512, set below.
  local parent tmp actual
  parent="$(dirname "$TEMPLATES_DIR")"
  mkdir -p "$parent"
  tmp="$(mktemp -d "$parent/.download-$TEMPLATES_TAG.XXXXXX")"
  # shellcheck disable=SC2064  # expand $tmp now: it is local and gone by the time EXIT fires.
  trap "rm -rf '$tmp'" EXIT

  echo "Downloading $TEMPLATES_FILE (about 1 GB, once per machine)" >&2
  curl --fail --location --silent --show-error --retry 3 --output "$tmp/$TEMPLATES_FILE" "$TEMPLATES_URL"

  actual="$(sha512_of "$tmp/$TEMPLATES_FILE")"
  if [[ "$actual" != "$TEMPLATES_SHA512" ]]; then
    echo "build.sh: checksum mismatch for $TEMPLATES_FILE; refusing to install." >&2
    echo "  expected $TEMPLATES_SHA512" >&2
    echo "  got      $actual" >&2
    exit 1
  fi

  unzip -q "$tmp/$TEMPLATES_FILE" -d "$tmp/unpacked"
  rm -f "$tmp/$TEMPLATES_FILE"
  if [[ "$(tr -d '[:space:]' < "$tmp/unpacked/templates/version.txt")" != "$TEMPLATES_TAG" ]]; then
    echo "build.sh: $TEMPLATES_FILE is not version $TEMPLATES_TAG; refusing to install." >&2
    exit 1
  fi
  rm -rf "$TEMPLATES_DIR"
  mv "$tmp/unpacked/templates" "$TEMPLATES_DIR"
  echo "Installed export templates in $TEMPLATES_DIR" >&2
}

# read_presets: prints one line per preset in PRESETS_FILE, "<name><TAB><export_path>", in file
# order. Only the top-level keys of each [preset.N] section are read, never [preset.N.options].
read_presets() {
  awk '
    /^\[preset\.[0-9]+\]$/ { in_preset = 1; name = ""; path = ""; next }
    /^\[/ { in_preset = 0; next }
    in_preset && /^name="/ { name = $0; sub(/^name="/, "", name); sub(/"$/, "", name) }
    in_preset && /^export_path="/ { path = $0; sub(/^export_path="/, "", path); sub(/"$/, "", path) }
    in_preset && name != "" && path != "" { print name "\t" path; in_preset = 0 }
  ' "$PRESETS_FILE"
}

# is_wanted NAME: succeeds when preset NAME should be exported (no names given, or NAME was given).
is_wanted() {
  # w: one name from the command line.
  local w
  [[ "${#wanted[@]}" -eq 0 ]] && return 0
  for w in "${wanted[@]}"; do
    [[ "$w" == "$1" ]] && return 0
  done
  return 1
}

# Refuse a preset name that is not in PRESETS_FILE before downloading templates or exporting.
# all_presets: every "<name><TAB><export_path>" line of PRESETS_FILE. w: one wanted name.
all_presets="$(read_presets)"
for w in ${wanted[@]+"${wanted[@]}"}; do
  if ! cut -f1 <<<"$all_presets" | grep -qxF -- "$w"; then
    echo "build.sh: no preset named '$w' in export_presets.cfg. Presets:" >&2
    cut -f1 <<<"$all_presets" | sed 's/^/  /' >&2
    exit 2
  fi
done

install_templates

# A fresh checkout has no .godot/ yet; class_name scripts need the import (as in tools/test.sh).
# import_log: Godot's import output, shown only when the import fails.
if ! import_log="$("$GODOT" --headless --path "$REPO_ROOT" --import 2>&1)"; then
  echo "$import_log" >&2
  echo "build.sh: godot --import failed." >&2
  exit 1
fi

mkdir -p "$BUILD_DIR"
# .gdignore tells Godot not to scan build/, so exported files never get imported into the project.
touch "$BUILD_DIR/.gdignore"

# failed: names of the presets whose export failed. linux_binary: the Linux build's path, for --check.
failed=()
linux_binary=""
# exported: how many presets were exported (0 means export_presets.cfg had none we could read).
exported=0
# out_dirs: the folders of the presets that exported, for the size summary.
out_dirs=()
# name, path: one preset's name and export_path (relative to REPO_ROOT), from all_presets.
while IFS=$'\t' read -r name path; do
  if [[ -z "$name" ]] || ! is_wanted "$name"; then
    continue
  fi
  # out_dir: the preset's own folder, emptied first so no file from an older build is shipped.
  out_dir="$(dirname "$REPO_ROOT/$path")"
  case "$out_dir/" in
    "$BUILD_DIR"/?*/) ;;
    *)
      echo "build.sh: preset '$name' exports to '$path', outside a build/<folder>/; refusing." >&2
      failed+=("$name")
      continue ;;
  esac
  rm -rf "$out_dir"
  mkdir -p "$out_dir"
  echo "Exporting '$name' to $path" >&2
  # log: Godot's output for this export, shown only when it fails.
  if ! log="$("$GODOT" --headless --path "$REPO_ROOT" --export-release "$name" "$REPO_ROOT/$path" 2>&1)" \
      || [[ ! -s "$REPO_ROOT/$path" ]]; then
    echo "$log" >&2
    echo "build.sh: export of '$name' failed." >&2
    # Remove the partial output so nobody ships a half-written build by mistake.
    rm -rf "$out_dir"
    failed+=("$name")
    continue
  fi
  exported=$((exported + 1))
  out_dirs+=("$out_dir")
  if [[ "$name" == "Linux" ]]; then
    linux_binary="$REPO_ROOT/$path"
  fi
done <<<"$all_presets"

if [[ "$exported" -eq 0 && "${#failed[@]}" -eq 0 ]]; then
  echo "build.sh: no presets found in $PRESETS_FILE." >&2
  exit 1
fi
if [[ "${#failed[@]}" -gt 0 ]]; then
  echo "build.sh: ${#failed[@]} export(s) failed: ${failed[*]}" >&2
  exit 1
fi
echo "Exported $exported preset(s):" >&2
du -sh "${out_dirs[@]}" >&2

if [[ "$check" -eq 0 ]]; then
  exit 0
fi

# --check: run the Linux build headless for QUIT_AFTER_FRAMES frames. It passes when the game exits
# with code 0 and prints no engine or script error (a missing script or data file shows up there).
if [[ "$(uname -s)/$(uname -m)" != "Linux/x86_64" ]]; then
  echo "build.sh: --check runs the Linux x86_64 build, so it needs a Linux x86_64 machine." >&2
  exit 1
fi
if [[ -z "$linux_binary" ]]; then
  echo "build.sh: --check runs the 'Linux' preset; export it too (it is in every full build)." >&2
  exit 1
fi
# home: a throwaway user data folder, so the smoke run neither reads nor writes the tester's real
# save, settings or logs (user://, see tools/README.md).
home="$(mktemp -d)"
# status: the smoke run's exit code. output: everything it printed.
status=0
output="$(cd "$home" && HOME="$home" XDG_DATA_HOME="$home/data" XDG_CONFIG_HOME="$home/config" \
  XDG_CACHE_HOME="$home/cache" timeout "$CHECK_TIMEOUT_SECONDS" \
  "$linux_binary" --headless --quit-after "$QUIT_AFTER_FRAMES" 2>&1)" || status=$?
rm -rf "$home"
echo "$output"
if [[ "$status" -ne 0 ]]; then
  echo "build.sh: smoke test failed: the Linux build exited with code $status." >&2
  exit 1
fi
if grep -qE '(^|[^A-Z_])(ERROR|SCRIPT ERROR|Parse Error)' <<<"$output"; then
  echo "build.sh: smoke test failed: the Linux build printed an error (above)." >&2
  exit 1
fi
echo "Smoke test passed: the Linux build started headless and quit cleanly." >&2
