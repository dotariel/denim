#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

unset BUILD_VERSION

# Default test version must NOT be 0.0.0 — that's app.go's compile-time
# fallback (before -X injection), so a broken ldflags path would silently
# print the same "0.0.0" and this check would pass for the wrong reason.
V="${1:-1.2.3}"
DATE="$(git log -1 --format=%cI)"

if command -v shasum >/dev/null 2>&1; then
  SHA256() { shasum -a 256 "$@"; }
else
  SHA256() { sha256sum "$@"; }
fi

HOSTOS="$(cd src && go env GOHOSTOS)"
HOSTARCH="$(cd src && go env GOHOSTARCH)"

TMPDIR_CHECK="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_CHECK"' EXIT

fail() {
  echo "FAIL: $1: $2" >&2
  exit 1
}

pass() {
  echo "PASS: $1"
}

# (1) The VERSION file is gone and the Makefile no longer reads it (D-05).
if [ -e VERSION ]; then
  fail "version-file-removed" "VERSION file still exists"
fi
if grep -qE 'PROJECT_DIR\)/VERSION' Makefile; then
  fail "version-file-removed" "Makefile still reads \$(PROJECT_DIR)/VERSION"
fi
pass "version-file-removed"

# (2) Makefile contains no Go module get invocation (BUILD-01).
if grep -qE 'go get' Makefile; then
  fail "no-go-get-in-makefile" "Makefile still invokes 'go get'"
fi
pass "no-go-get-in-makefile"

# (3) go.mod/go.sum immutability across a clean make dist (BUILD-01).
SHA256 src/go.mod src/go.sum > "$TMPDIR_CHECK/gosum-before.sha256"
make clean >/dev/null
make dist BUILD_VERSION="$V" >/dev/null
SHA256 src/go.mod src/go.sum > "$TMPDIR_CHECK/gosum-after.sha256"
if ! diff -q "$TMPDIR_CHECK/gosum-before.sha256" "$TMPDIR_CHECK/gosum-after.sha256" >/dev/null; then
  fail "go-sum-immutable" "src/go.mod or src/go.sum changed during make dist"
fi
pass "go-sum-immutable"

# (4) gen/dist holds exactly the five expected names (BUILD-02, D-05).
EXPECTED_NAMES="denim_darwin_amd64 denim_darwin_arm64 denim_linux_amd64 denim_linux_arm64 denim_windows_amd64.exe"
ACTUAL_NAMES="$(ls gen/dist | LC_ALL=C sort | tr '\n' ' ' | sed 's/ *$//')"
if [ "$ACTUAL_NAMES" != "$EXPECTED_NAMES" ]; then
  fail "dist-file-set" "expected [$EXPECTED_NAMES], got [$ACTUAL_NAMES]"
fi
pass "dist-file-set"

# (5) file output matches OS/arch per binary (BUILD-02, D-07). Tokens are
# checked independently because GNU file and BSD file order them differently.
check_file_type() {
  local path="$1"
  local want1="$2"
  local want2="$3"
  local out
  out="$(file "$path")"
  case "$out" in
    *"$want1"*) ;;
    *) fail "file-type:$path" "expected token '$want1' not found in: $out" ;;
  esac
  case "$out" in
    *"$want2"*) ;;
    *) fail "file-type:$path" "expected token '$want2' not found in: $out" ;;
  esac
}

check_file_type "gen/dist/denim_darwin_amd64" "Mach-O" "x86_64"
check_file_type "gen/dist/denim_darwin_arm64" "Mach-O" "arm64"
check_file_type "gen/dist/denim_linux_amd64" "ELF" "x86-64"
check_file_type "gen/dist/denim_linux_arm64" "ELF" "aarch64"
check_file_type "gen/dist/denim_windows_amd64.exe" "PE32+" "x86-64"
pass "file-type-per-arch"

# (6) End-to-end: host binary's stdout matches exactly, ends with a newline,
# and stderr is empty (BUILD-04, D-01, D-04).
HOST_BIN=""
if [ "$HOSTOS" = "darwin" ] || [ "$HOSTOS" = "linux" ]; then
  HOST_BIN="gen/dist/denim_${HOSTOS}_${HOSTARCH}"
  if [ ! -x "$HOST_BIN" ]; then
    fail "host-binary-exists" "$HOST_BIN not found or not executable"
  fi

  HOST_OUT_FILE="$TMPDIR_CHECK/host.out"
  HOST_ERR_FILE="$TMPDIR_CHECK/host.err"
  "$HOST_BIN" version > "$HOST_OUT_FILE" 2> "$HOST_ERR_FILE"

  EXPECTED_STDOUT="denim v$V ($DATE)"
  ACTUAL_STDOUT="$(cat "$HOST_OUT_FILE")"
  if [ "$ACTUAL_STDOUT" != "$EXPECTED_STDOUT" ]; then
    fail "host-stdout" "expected [$EXPECTED_STDOUT], got [$ACTUAL_STDOUT]"
  fi

  LAST_BYTE="$(tail -c1 "$HOST_OUT_FILE" | od -An -tx1 | tr -d ' ')"
  if [ "$LAST_BYTE" != "0a" ]; then
    fail "host-stdout-trailing-newline" "last byte was 0x$LAST_BYTE, expected 0x0a"
  fi

  if [ -s "$HOST_ERR_FILE" ]; then
    fail "host-stderr-empty" "stderr was not empty: $(cat "$HOST_ERR_FILE")"
  fi

  pass "host-version-stdout"
else
  pass "host-version-stdout-skipped-unsupported-host-os"
fi

# (7) No binary leaks the repo's absolute path (D-13 -trimpath); the host
# binary's buildinfo carries no vcs. lines (D-13 -buildvcs=false).
for bin in gen/dist/*; do
  if grep -qa -F "$REPO_ROOT" "$bin"; then
    fail "no-leaked-path:$bin" "binary contains repo absolute path"
  fi
done
pass "no-leaked-path"

if [ -n "$HOST_BIN" ]; then
  if go version -m "$HOST_BIN" | grep -q 'vcs\.'; then
    fail "no-vcs-stamp" "$HOST_BIN buildinfo contains vcs. lines"
  fi
  pass "no-vcs-stamp"
else
  pass "no-vcs-stamp-skipped-unsupported-host-os"
fi

# (8) Two clean builds produce byte-identical output (D-14). Compares the
# full `hash  filename` line for both runs (01-REVIEW WR-02) rather than
# just the sorted hash column, so a build that swapped bytes between two
# same-hash-set binaries would still be caught.
SHA256 gen/dist/* > "$TMPDIR_CHECK/run1.sha256"
make clean >/dev/null
make dist BUILD_VERSION="$V" >/dev/null
SHA256 gen/dist/* > "$TMPDIR_CHECK/run2.sha256"

if ! diff <(sort "$TMPDIR_CHECK/run1.sha256") <(sort "$TMPDIR_CHECK/run2.sha256") >/dev/null; then
  fail "reproducible-build" "sha256 output differs between two clean make dist runs"
fi
pass "reproducible-build"

# (9) Default (no override) build prints the git-describe dev version
# string (D-05). A shallow, tagless clone makes `git describe` fall back
# to a bare short hash with no leading v (RESEARCH Pitfall 4) — this still
# matches because the Makefile computes BUILD_VERSION the exact same way.
make build >/dev/null
DEV_VERSION="$(git describe --tags --always --dirty | sed 's/^v//')"
EXPECTED_DEV="denim v$DEV_VERSION ($DATE)"
ACTUAL_DEV="$(gen/denim version)"
if [ "$ACTUAL_DEV" != "$EXPECTED_DEV" ]; then
  fail "dev-version-string" "expected [$EXPECTED_DEV], got [$ACTUAL_DEV]"
fi
pass "dev-version-string"

# (10) Packaging: gen/dist -> gen/release archives + SHA256SUMS (D-06).
# Uses the gen/dist produced by check (8)'s last `make dist BUILD_VERSION=$V`.
rm -rf gen/release
scripts/package-release.sh >/dev/null

EXPECTED_RELEASE_NAMES="SHA256SUMS denim_darwin_amd64.tar.gz denim_darwin_arm64.tar.gz denim_linux_amd64.tar.gz denim_linux_arm64.tar.gz denim_windows_amd64.zip"
ACTUAL_RELEASE_NAMES="$(cd gen/release && ls | LC_ALL=C sort | tr '\n' ' ' | sed 's/ *$//')"
if [ "$ACTUAL_RELEASE_NAMES" != "$EXPECTED_RELEASE_NAMES" ]; then
  fail "release-archives" "expected [$EXPECTED_RELEASE_NAMES], got [$ACTUAL_RELEASE_NAMES]"
fi

for pair in darwin_amd64 darwin_arm64 linux_amd64 linux_arm64; do
  LISTING="$(tar -tvzf "gen/release/denim_${pair}.tar.gz")"
  ENTRY_COUNT="$(printf '%s\n' "$LISTING" | wc -l | tr -d ' ')"
  if [ "$ENTRY_COUNT" -ne 1 ]; then
    fail "release-archives" "denim_${pair}.tar.gz has $ENTRY_COUNT entries, expected 1"
  fi
  ENTRY_NAME="$(printf '%s\n' "$LISTING" | awk '{print $NF}')"
  if [ "$ENTRY_NAME" != "denim" ]; then
    fail "release-archives" "denim_${pair}.tar.gz entry is named '$ENTRY_NAME', expected 'denim'"
  fi
  case "$LISTING" in
    -rwx*) ;;
    *) fail "release-archives" "denim_${pair}.tar.gz entry is not executable: $LISTING" ;;
  esac
done

ZIP_LISTING="$(unzip -Z1 gen/release/denim_windows_amd64.zip)"
if [ "$ZIP_LISTING" != "denim.exe" ]; then
  fail "release-archives" "zip listing expected exactly 'denim.exe', got [$ZIP_LISTING]"
fi

SUMS_LINES="$(wc -l < gen/release/SHA256SUMS | tr -d ' ')"
if [ "$SUMS_LINES" -ne 5 ]; then
  fail "release-archives" "SHA256SUMS has $SUMS_LINES lines, expected 5"
fi

if ! (cd gen/release && SHA256 -c SHA256SUMS); then
  fail "release-archives" "SHA256SUMS check failed"
fi

if [ -n "$HOST_BIN" ]; then
  EXTRACT_DIR="$TMPDIR_CHECK/extract"
  mkdir -p "$EXTRACT_DIR"
  tar -C "$EXTRACT_DIR" -xzf "gen/release/denim_${HOSTOS}_${HOSTARCH}.tar.gz"
  RELEASE_BIN_OUT="$("$EXTRACT_DIR/denim" version)"
  EXPECTED_RELEASE_OUT="denim v$V ($DATE)"
  if [ "$RELEASE_BIN_OUT" != "$EXPECTED_RELEASE_OUT" ]; then
    fail "release-archives" "expected [$EXPECTED_RELEASE_OUT], got [$RELEASE_BIN_OUT]"
  fi
fi

pass "release-archives"

# (11) Two packaging runs produce byte-identical tar.gz archives. The zip
# is excluded — zip stores per-entry timestamps that vary run to run.
SHA256 gen/release/denim_darwin_amd64.tar.gz gen/release/denim_darwin_arm64.tar.gz gen/release/denim_linux_amd64.tar.gz gen/release/denim_linux_arm64.tar.gz > "$TMPDIR_CHECK/pkg-run1.sha256"
scripts/package-release.sh >/dev/null
SHA256 gen/release/denim_darwin_amd64.tar.gz gen/release/denim_darwin_arm64.tar.gz gen/release/denim_linux_amd64.tar.gz gen/release/denim_linux_arm64.tar.gz > "$TMPDIR_CHECK/pkg-run2.sha256"

if ! diff <(sort "$TMPDIR_CHECK/pkg-run1.sha256") <(sort "$TMPDIR_CHECK/pkg-run2.sha256") >/dev/null; then
  fail "reproducible-archives" "tar.gz sha256 output differs between two package-release.sh runs"
fi
pass "reproducible-archives"

echo "verify-dist: ALL CHECKS PASSED"
