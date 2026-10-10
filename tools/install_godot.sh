#!/usr/bin/env bash
# Installs the pinned Godot into .tools/ and prints the path of the binary.
# Lane: tools (Agent B). The version pin and checksums are a shared contract: change them only in
# a small PR of their own, approved by the other person.
#
# Usage: tools/install_godot.sh          # installs if missing, then prints the binary path
# Safe to run again: it does nothing when the right binary is already installed.
set -euo pipefail

# GODOT_VERSION: the pinned release tag, without the "-stable" suffix. Shared contract.
GODOT_VERSION="4.7.2"
# REPO_ROOT: the repository root, found from this script's own location.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# INSTALL_DIR: where this version is unpacked. .tools/ is git-ignored.
INSTALL_DIR="$REPO_ROOT/.tools/godot-$GODOT_VERSION"

# os, arch: this machine, as uname reports them.
os="$(uname -s)"
arch="$(uname -m)"
# zip: the release file for this machine. bin: the binary's path inside INSTALL_DIR.
# sha: the file's SHA-512, copied from the release's SHA512-SUMS.txt.
case "$os/$arch" in
  Linux/x86_64)
    zip="Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
    bin="Godot_v${GODOT_VERSION}-stable_linux.x86_64"
    sha="9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65" ;;
  Linux/aarch64|Linux/arm64)
    zip="Godot_v${GODOT_VERSION}-stable_linux.arm64.zip"
    bin="Godot_v${GODOT_VERSION}-stable_linux.arm64"
    sha="dd59918da086bd49bde2f5450b5e567ff8650cbde9abbd7b8f4ca1197ff8c609baa38834666d032deafb47099078d7822279e2a0e06e5665745468f26533e7e2" ;;
  Darwin/*)
    zip="Godot_v${GODOT_VERSION}-stable_macos.universal.zip"
    bin="Godot.app/Contents/MacOS/Godot"
    sha="38aa16e5bba2083941fc5b3e54be0089bd4cc35e32415f5b9fd9a8a6a7b9818255d44532ea8ef94b5aef56c4b407c2d634fa4f657e4ebe681ebbf59b7bac69ca" ;;
  *)
    echo "install_godot.sh: no pinned Godot build for $os/$arch." >&2
    echo "On Windows, download Godot_v${GODOT_VERSION}-stable_win64.exe.zip from the official" >&2
    echo "GitHub release, check its SHA-512 against tasks/002, and unzip it into $INSTALL_DIR." >&2
    exit 1 ;;
esac

if [[ -x "$INSTALL_DIR/$bin" ]]; then
  echo "$INSTALL_DIR/$bin"
  exit 0
fi

# url: the official release download.
url="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/$zip"
# tmp: a scratch folder for the download, removed on exit.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Downloading $zip" >&2
curl --fail --location --silent --show-error --retry 3 --output "$tmp/$zip" "$url"

# actual: the downloaded file's SHA-512.
if command -v sha512sum >/dev/null; then
  actual="$(sha512sum "$tmp/$zip" | cut -d' ' -f1)"
else
  actual="$(shasum -a 512 "$tmp/$zip" | cut -d' ' -f1)"
fi
if [[ "$actual" != "$sha" ]]; then
  echo "install_godot.sh: checksum mismatch for $zip; refusing to install." >&2
  echo "  expected $sha" >&2
  echo "  got      $actual" >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR"
unzip -q -o "$tmp/$zip" -d "$INSTALL_DIR"
chmod +x "$INSTALL_DIR/$bin"
echo "$INSTALL_DIR/$bin"
