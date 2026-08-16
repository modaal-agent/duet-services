#!/usr/bin/env bash
# © 2026 Modaal. All rights reserved.
#
# Install the .mintfile-pinned Swift CLI tools from their prebuilt release
# artifacts instead of compiling them from source with Mint.
#
# `mint bootstrap -m scripts/.mintfile` builds XcodeGen and xcbeautify with SwiftPM:
# two release builds, ~8 minutes on a cold macOS runner, before any app code
# compiles. The ~/.mint cache only helps once a run reaches its post-step, which a
# cancelled run does not. Both projects publish universal macOS binaries on their
# GitHub releases: ~7s cold, ~1s warm, no toolchain required.
#
# Versions stay in scripts/.mintfile, so plain `mint` and this script cannot
# disagree. Bumping a version there is the whole edit.
#
# Usage:
#   scripts/install-swift-tools.sh              # install the build tools (xcodegen, xcbeautify)
#   scripts/install-swift-tools.sh sourcery     # or just the ones named
#   "$(scripts/install-swift-tools.sh --bin-dir)"/xcodegen --version
#
# `sourcery` is pinned here but NOT in the no-argument set: its artifact bundle is
# 59 MB and only scripts/generate-mocks.sh needs it, which asks for it by name.
# The app-tree jobs that call this script with no arguments would otherwise
# download it on every run and use it for nothing.
#
# Installs into .build/tools/ (gitignored; override with SWIFT_TOOLS_DIR).
# Idempotent: a tool already at the pinned version costs one --version call.
#
# macOS only. On other platforms it exits 0 having done nothing, so a shared script
# can call it unconditionally.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MINTFILE="$SCRIPT_DIR/.mintfile"

TOOLS_DIR="${SWIFT_TOOLS_DIR:-$GIT_ROOT/.build/tools}"
BIN_DIR="$TOOLS_DIR/bin"

if [[ "${1:-}" == "--bin-dir" ]]; then
  echo "$BIN_DIR"
  exit 0
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "install-swift-tools: not macOS — nothing to do." >&2
  exit 0
fi

if [[ ! -f "$MINTFILE" ]]; then
  echo "install-swift-tools: no pin file at $MINTFILE" >&2
  exit 2
fi

# The pinned version for a `owner/Repo@version` line, ignoring comments (both
# whole-line and trailing). Empty means "not pinned / commented out".
pinned_version() {
  local slug="$1"
  sed 's/#.*//' "$MINTFILE" \
    | tr -d '[:blank:]' \
    | awk -F@ -v want="$slug" 'tolower($1) == tolower(want) { print $2; exit }'
}

# Is $1 already at version $2? XcodeGen prints "Version: 2.43.0" and xcbeautify
# prints "2.16.0", so match the version as a whole word anywhere in the output
# rather than parsing each format.
already_at() {
  local bin="$1" want="$2"
  [[ -x "$bin" ]] || return 1
  "$bin" --version 2>/dev/null | grep -qE "(^|[^0-9.])${want//./\\.}([^0-9.]|$)"
}

fetch_and_unpack() {  # url, dest_dir
  local url="$1" dest="$2"
  mkdir -p "$dest"
  # --retry: this is the step's only network hop; a transient 5xx should not fail
  # the job.
  curl --fail --silent --show-error --location --retry 3 --retry-delay 2 \
    -o "$dest/download.zip" "$url"
  unzip -q -o "$dest/download.zip" -d "$dest"
}

install_xcodegen() {
  local want="$1" bin="$BIN_DIR/xcodegen"
  if already_at "$bin" "$want"; then
    echo "install-swift-tools: xcodegen $want already installed" >&2
    return
  fi
  echo "install-swift-tools: fetching prebuilt xcodegen $want" >&2
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  fetch_and_unpack \
    "https://github.com/yonaskolb/XcodeGen/releases/download/${want}/xcodegen.zip" "$tmp"
  # XcodeGen resolves its SettingPresets relative to its own location
  # (../share/xcodegen), so bin/ and share/ install together. The binary alone
  # generates projects with no default settings.
  mkdir -p "$BIN_DIR" "$TOOLS_DIR/share"
  rm -rf "$TOOLS_DIR/share/xcodegen"
  mv "$tmp/xcodegen/bin/xcodegen" "$bin"
  mv "$tmp/xcodegen/share/xcodegen" "$TOOLS_DIR/share/xcodegen"
  chmod +x "$bin"
}

install_xcbeautify() {
  local want="$1" bin="$BIN_DIR/xcbeautify"
  if already_at "$bin" "$want"; then
    echo "install-swift-tools: xcbeautify $want already installed" >&2
    return
  fi
  echo "install-swift-tools: fetching prebuilt xcbeautify $want" >&2
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  fetch_and_unpack \
    "https://github.com/cpisciotta/xcbeautify/releases/download/${want}/xcbeautify-${want}-universal-apple-macosx.zip" "$tmp"
  mkdir -p "$BIN_DIR"
  mv "$tmp/release/xcbeautify" "$bin"
  chmod +x "$bin"
}

install_sourcery() {
  local want="$1" bin="$BIN_DIR/sourcery"
  if already_at "$bin" "$want"; then
    echo "install-swift-tools: sourcery $want already installed" >&2
    return
  fi
  echo "install-swift-tools: fetching prebuilt sourcery $want" >&2
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  fetch_and_unpack \
    "https://github.com/krzysztofzablocki/Sourcery/releases/download/${want}/sourcery-${want}.artifactbundle.zip" "$tmp"
  # sourcery evaluates .swifttemplate files through EJS and loads ejs.js from its
  # own bin directory, so the two files install together. The rest of the bundle
  # (stock Templates/, the docset, Resources/) is not used: generate-mocks.sh
  # passes --templates explicitly.
  mkdir -p "$BIN_DIR"
  mv "$tmp/sourcery-${want}.artifactbundle/sourcery/bin/sourcery" "$bin"
  mv "$tmp/sourcery-${want}.artifactbundle/sourcery/bin/ejs.js" "$BIN_DIR/ejs.js"
  chmod +x "$bin"
}

WANTED=("$@")
if [[ ${#WANTED[@]} -eq 0 ]]; then
  WANTED=(xcodegen xcbeautify)
fi

for tool in "${WANTED[@]}"; do
  case "$tool" in
    xcodegen)
      version="$(pinned_version yonaskolb/XcodeGen)"
      [[ -n "$version" ]] || { echo "install-swift-tools: XcodeGen is not pinned in $MINTFILE" >&2; exit 2; }
      install_xcodegen "$version"
      ;;
    xcbeautify)
      version="$(pinned_version cpisciotta/xcbeautify)"
      [[ -n "$version" ]] || { echo "install-swift-tools: xcbeautify is not pinned in $MINTFILE" >&2; exit 2; }
      install_xcbeautify "$version"
      ;;
    sourcery)
      version="$(pinned_version krzysztofzablocki/Sourcery)"
      [[ -n "$version" ]] || { echo "install-swift-tools: Sourcery is not pinned in $MINTFILE" >&2; exit 2; }
      install_sourcery "$version"
      ;;
    *)
      echo "install-swift-tools: unknown tool '$tool' (known: xcodegen, xcbeautify, sourcery)" >&2
      echo "  Add an install_* function here when a new .mintfile entry needs one." >&2
      exit 2
      ;;
  esac
done

echo "install-swift-tools: ready — $BIN_DIR" >&2
