#!/bin/bash
# Copyright (c) 2026 Modaal.dev
# Licensed under the MIT License. See LICENSE file for details.
#
# Generate this repo's Swift code that is derived from its own protocols, using
# the swift-sourcery-templates release bundle at the tag pinned below. One
# kind, from one annotation:
#
#   /// sourcery: CreateMock      the test double a spec drives
#
# See `GENERATORS` below for what it writes and where.
#
# Usage:
#   scripts/generate-mocks.sh            # regenerate in place
#   scripts/generate-mocks.sh --check    # prove the committed output current — no engine run
#
# Overrides, for local iteration only (a committed file comes from the pinned
# bundle — the fingerprint block records the pinned tag either way):
#   TEMPLATES_DIR=/path/to/swift-sourcery-templates/templates   a local templates checkout
#   SOURCERY=/path/to/sourcery                                  your own engine build
#   MOCK_TEMPLATES=/path/to/mock-templates                      your own CLI build
#
# THIS SCRIPT IS THE ENTRY POINT. CI's `codegen` job and the agent docs call it
# by name and never invoke the tools directly, so swapping the engine is a
# change to this file alone.
#
# The output is a BUILD PRODUCT: never hand-edit a file under Generated/.
# Change the protocol, or re-pin the bundle, and re-run this script. Each
# generated file starts with a fingerprint block (bundle tag, generator
# config, path + SHA-256 of every scanned source, SHA-256 of the body);
# `--check` re-hashes that list and the body, so a stale input, a file added
# after generation, and a hand-edit all turn CI red without a Sourcery run.
#
# A protocol declared inside a platform-conditional block (`#if canImport`,
# `#if os`) must NOT carry an annotation: the generated file is unconditional,
# so the other platform's lane cannot compile the result. Hand-write those
# doubles.

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Configuration ─────────────────────────────────────────────────
# One release asset provisions everything: the swift-sourcery-templates
# artifact bundle carries the Sourcery engine, the templates/ tree and the
# mock-templates CLI, pinned together by one tag — there is no engine/template
# version pair to keep matched. Pinned by tag + checksum, not by branch: the
# generated files are committed, so a template change must arrive as a
# deliberate re-pin commit (both checksums move with the tag) carrying a
# fresh diff.
BUNDLE_REPO="https://github.com/modaal-agent/swift-sourcery-templates"
BUNDLE_TAG="0.6.0"
BUNDLE_ZIP_SHA256="998590da08d9a6427e4c5144bb63ed3167f187855bc373037833d761745f6b3f"
# The CLI zipped alone: `--check` runs no engine, so that path downloads
# kilobytes instead of the ~60 MB bundle.
CLI_ZIP_SHA256="8eb49ca7f616f321a2c600a828cd8eab2aee9d91ed469c969f79db4bfea69885"

TOOLS_CACHE="$GIT_ROOT/.build/swift-sourcery-templates-$BUNDLE_TAG"
BUNDLE_DIR="$TOOLS_CACHE/swift-sourcery-templates-$BUNDLE_TAG.artifactbundle"
TEMPLATES_DIR="${TEMPLATES_DIR:-$BUNDLE_DIR/templates}"

# Where a published Duet checkout is cached when the script has to fetch it
# itself (the manifest's local-path phase needs no clone).
DUET_CACHE="$GIT_ROOT/.build/duet-sources"

# ── The generators ────────────────────────────────────────────────
# One entry per generated file. Each is a function that sets:
#
#   OUT_DIR / OUT_FILE   where it lands. A generated file is a source file of
#                        the target it sits in, so this is what decides which
#                        module can see the emitted types.
#   TEMPLATE             the entry point in the bundle's templates/ tree.
#   SOURCE_ROOTS         what Sourcery parses. A Component entry scans its own
#                        package alone — the template filters by annotation and
#                        nothing else, so a wider scan would emit another
#                        package's Components into this file, where that
#                        package's own Builder cannot see them.
#   TEMPLATE_ARGS        the imports the emitted file needs. Sourcery cannot
#                        infer them: it sees the protocol's source text, not
#                        the module a referenced type resolves to. An import
#                        the output does not use is inert; a missing one is a
#                        build error.
GENERATORS=(
  services_mocks
)

# The shared services' test doubles: every platform-neutral protocol annotated
# `CreateMock`, in one file in the Services test target.
generator_services_mocks() {
  OUT_DIR="$GIT_ROOT/Tests/ServicesTests/Generated"
  OUT_FILE="ServicesMocks.swift"
  TEMPLATE="Mocks.swifttemplate"
  derive_source_roots "$GIT_ROOT"
  SOURCE_ROOTS=("${DERIVED_SOURCE_ROOTS[@]}")
  TEMPLATE_ARGS=(
    --args "import=Analytics"
    --args "import=AppServices"
    --args "import=Combine"     # AnyCancellable
    --args "import=Diagnostics"
    --args "import=DuetShells"  # Working
    --args "import=Foundation"
  )
}

CHECK=0
[ "$1" = "--check" ] && CHECK=1

# ── Tools ─────────────────────────────────────────────────────────
fetch_verified() {  # <url> <sha256> <dest>
  curl -fsSL -o "$3" "$1"
  echo "$2  $3" | shasum -a 256 -c - >/dev/null 2>&1 || {
    echo "generate-mocks: checksum mismatch for $1" >&2
    exit 1
  }
}

# Regeneration needs the full bundle (engine + templates + CLI); validation
# needs only the CLI. Either path honors the overrides above.
provision_bundle() {
  # Nothing to fetch when every piece is overridden.
  if [ -n "$MOCK_TEMPLATES" ] && [ -n "$SOURCERY" ] && [ "$TEMPLATES_DIR" != "$BUNDLE_DIR/templates" ]; then
    return
  fi
  if [ ! -x "$BUNDLE_DIR/mock-templates/bin/mock-templates" ]; then
    echo "Fetching swift-sourcery-templates bundle $BUNDLE_TAG..."
    rm -rf "$TOOLS_CACHE"
    mkdir -p "$TOOLS_CACHE"
    fetch_verified \
      "$BUNDLE_REPO/releases/download/$BUNDLE_TAG/swift-sourcery-templates-$BUNDLE_TAG.artifactbundle.zip" \
      "$BUNDLE_ZIP_SHA256" "$TOOLS_CACHE/bundle.zip"
    unzip -q "$TOOLS_CACHE/bundle.zip" -d "$TOOLS_CACHE"
    rm "$TOOLS_CACHE/bundle.zip"
  fi
  MOCK_TEMPLATES="${MOCK_TEMPLATES:-$BUNDLE_DIR/mock-templates/bin/mock-templates}"
  SOURCERY="${SOURCERY:-$BUNDLE_DIR/sourcery/bin/sourcery}"
}

provision_cli() {
  # A full bundle cached by a regenerate run already holds the same binary.
  if [ -z "$MOCK_TEMPLATES" ] && [ -x "$BUNDLE_DIR/mock-templates/bin/mock-templates" ]; then
    MOCK_TEMPLATES="$BUNDLE_DIR/mock-templates/bin/mock-templates"
  fi
  if [ -z "$MOCK_TEMPLATES" ]; then
    if [ ! -x "$TOOLS_CACHE/cli/mock-templates" ]; then
      echo "Fetching mock-templates $BUNDLE_TAG..."
      mkdir -p "$TOOLS_CACHE/cli"
      fetch_verified \
        "$BUNDLE_REPO/releases/download/$BUNDLE_TAG/mock-templates-$BUNDLE_TAG-macos.zip" \
        "$CLI_ZIP_SHA256" "$TOOLS_CACHE/cli.zip"
      unzip -q "$TOOLS_CACHE/cli.zip" -d "$TOOLS_CACHE/cli"
      rm "$TOOLS_CACHE/cli.zip"
    fi
    MOCK_TEMPLATES="$TOOLS_CACHE/cli/mock-templates"
  fi
}

if [ "$CHECK" -eq 1 ]; then provision_cli; else provision_bundle; fi
[ -x "$MOCK_TEMPLATES" ] || { echo "generate-mocks: no mock-templates executable at '$MOCK_TEMPLATES'" >&2; exit 1; }

if [ "$CHECK" -eq 1 ]; then
  echo "bundle $BUNDLE_TAG · mock-templates validate (no engine run)"
else
  echo "bundle $BUNDLE_TAG · sourcery $("$SOURCERY" --version) · templates $TEMPLATES_DIR"
fi

# ── The manifest-derived source set ───────────────────────────────
# Sourcery resolves an inherited requirement only from the declarations it
# parses. A protocol refining one from another module (`DiagnosticsWorking:
# Working`) therefore generates an INCOMPLETE mock unless that module's
# sources are on the command line — the failure lands in the test target as
# "does not conform to protocol".
#
# `derive_source_roots <package_dir>` fills DERIVED_SOURCE_ROOTS from the
# package MANIFEST (`swift package dump-package` — a manifest compile, no
# resolution, no network), never from a hand-written list:
#
#   - the package's own Sources/;
#   - every PATH dependency's Sources/ (the Duet family checkout keeps its
#     Swift half under swift/Sources — both spellings are tried);
#   - a published (URL + exact pin) Duet dependency, cloned at the pin when no
#     path form is present.
#
# `--check` walks the same rung: validation re-hashes the recorded inputs, so
# the same source set has to be on disk — seconds of clone, no toolchain.
#
# Remote third-party packages are deliberately out: none declares a protocol
# the annotated ones refine, and parsing them costs seconds per run for
# nothing.
read_manifest() {  # <manifest json> <python expression over `d`, printing lines>
  printf '%s' "$1" | python3 -c "
import json, sys
d = json.load(sys.stdin)
$2
"
}

derive_source_roots() {  # <package_dir>
  local package_dir="$1"
  local manifest_json
  manifest_json="$(cd "$package_dir" && swift package dump-package)"
  DERIVED_SOURCE_ROOTS=("$package_dir/Sources")

  local path
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    case "$path" in
      /*) ;;
      *) path="$package_dir/$path" ;;
    esac
    if [ -d "$path/Sources" ]; then
      DERIVED_SOURCE_ROOTS+=("$path/Sources")
    elif [ -d "$path/swift/Sources" ]; then
      DERIVED_SOURCE_ROOTS+=("$path/swift/Sources")
    else
      echo "generate-mocks: path dependency has no Sources/ — skipping $path" >&2
    fi
  done < <(read_manifest "$manifest_json" "
for dep in d['dependencies']:
    for fs in dep.get('fileSystem', []):
        print(fs['path'])
")

  # The published phase: duet arrives as URL + exact pin instead of a path.
  local duet_url duet_version
  duet_url="$(read_manifest "$manifest_json" "
for dep in d['dependencies']:
    for sc in dep.get('sourceControl', []):
        if sc['identity'] == 'duet':
            print(sc['location']['remote'][0]['urlString'])
")"
  duet_version="$(read_manifest "$manifest_json" "
for dep in d['dependencies']:
    for sc in dep.get('sourceControl', []):
        if sc['identity'] == 'duet':
            print(sc['requirement']['exact'][0])
")"
  if [ -n "$duet_url" ] && [ -n "$duet_version" ]; then
    local current="unknown"
    [ -d "$DUET_CACHE" ] && current=$(cd "$DUET_CACHE" && git describe --tags --exact-match 2>/dev/null || echo "unknown")
    if [ "$current" != "$duet_version" ]; then
      echo "Cloning duet@$duet_version..."
      rm -rf "$DUET_CACHE"
      git clone --quiet --depth 1 --branch "$duet_version" \
        -c advice.detachedHead=false "$duet_url" "$DUET_CACHE"
    fi
    for candidate in "swift/Sources" "Sources"; do
      if [ -d "$DUET_CACHE/$candidate" ]; then
        DERIVED_SOURCE_ROOTS+=("$DUET_CACHE/$candidate")
        break
      fi
    done
  fi
}

# ── Generate / validate ───────────────────────────────────────────
DRIFT=0

for generator in "${GENERATORS[@]}"; do
  "generator_$generator"

  sources_args=()
  for root in "${SOURCE_ROOTS[@]}"; do sources_args+=(--sources "$root"); done

  if [ "$CHECK" -eq 1 ]; then
    "$MOCK_TEMPLATES" validate \
      --file "$OUT_DIR/$OUT_FILE" \
      --root "$GIT_ROOT" \
      "${sources_args[@]}" \
      --expect-bundle "$BUNDLE_TAG" || DRIFT=1
  else
    [ -f "$TEMPLATES_DIR/$TEMPLATE" ] || { echo "generate-mocks: no $TEMPLATE at $TEMPLATES_DIR" >&2; exit 1; }
    mkdir -p "$OUT_DIR"
    "$MOCK_TEMPLATES" generate \
      "${sources_args[@]}" \
      --sourcery "$SOURCERY" \
      --templates "$TEMPLATES_DIR/$TEMPLATE" \
      "${TEMPLATE_ARGS[@]}" \
      --bundle-version "$BUNDLE_TAG" \
      --root "$GIT_ROOT" \
      --output "$OUT_DIR/$OUT_FILE"
    echo "  $OUT_FILE — $(grep -cE '^(final )?class ' "$OUT_DIR/$OUT_FILE") types, $(wc -l < "$OUT_DIR/$OUT_FILE" | tr -d ' ') lines"
  fi
done

# ── Check ─────────────────────────────────────────────────────────
if [ "$CHECK" -eq 1 ]; then
  if [ "$DRIFT" -eq 1 ]; then
    echo ""
    echo -e "\033[1;31mGenerated code is stale.\033[0m"
    echo "  A recorded input changed, a source file was added, or the output was"
    echo "  edited after generation. Run:"
    echo "    scripts/generate-mocks.sh"
    echo "  and commit the result — files under Generated/ are build products."
    exit 1
  fi
  echo -e "\033[0;32mGenerated code is current ✓\033[0m"
fi
