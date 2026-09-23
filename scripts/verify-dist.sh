#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

unset BUILD_VERSION

V="${1:-$(tr -d '\n' < VERSION)}"
DATE="$(git log -1 --format=%cI)"
SHA="$(git rev-parse --short HEAD)"

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

# (1) Makefile contains no Go module get invocation (BUILD-01).
if grep -qE 'go get' Makefile; then
  fail "no-go-get-in-makefile" "Makefile still invokes 'go get'"
fi
pass "no-go-get-in-makefile"

# (2) go.mod/go.sum immutability across a clean make dist (BUILD-01).
SHA256 src/go.mod src/go.sum > "$TMPDIR_CHECK/gosum-before.sha256"
make clean >/dev/null
make dist BUILD_VERSION="$V" >/dev/null
SHA256 src/go.mod src/go.sum > "$TMPDIR_CHECK/gosum-after.sha256"
if ! diff -q "$TMPDIR_CHECK/gosum-before.sha256" "$TMPDIR_CHECK/gosum-after.sha256" >/dev/null; then
  fail "go-sum-immutable" "src/go.mod or src/go.sum changed during make dist"
fi
pass "go-sum-immutable"

# (3) gen/dist holds exactly the five expected names (BUILD-02, D-05).
EXPECTED_NAMES="denim_darwin_amd64 denim_darwin_arm64 denim_linux_amd64 denim_linux_arm64 denim_windows_amd64.exe"
ACTUAL_NAMES="$(ls gen/dist | sort | tr '\n' ' ' | sed 's/ *$//')"
if [ "$ACTUAL_NAMES" != "$EXPECTED_NAMES" ]; then
  fail "dist-file-set" "expected [$EXPECTED_NAMES], got [$ACTUAL_NAMES]"
fi
pass "dist-file-set"

# (4) file output matches OS/arch per binary (BUILD-02, D-07). Tokens are
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

# (5) End-to-end: host binary's stdout matches exactly, ends with a newline,
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

# (6) No binary leaks the repo's absolute path (D-13 -trimpath); the host
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

# (7) Two clean builds produce byte-identical output (D-14).
SHA256 gen/dist/* > "$TMPDIR_CHECK/run1.sha256"
make clean >/dev/null
make dist BUILD_VERSION="$V" >/dev/null
SHA256 gen/dist/* > "$TMPDIR_CHECK/run2.sha256"

RUN1_HASHES="$(awk '{print $1}' "$TMPDIR_CHECK/run1.sha256" | sort)"
RUN2_HASHES="$(awk '{print $1}' "$TMPDIR_CHECK/run2.sha256" | sort)"
if [ "$RUN1_HASHES" != "$RUN2_HASHES" ]; then
  fail "reproducible-build" "sha256 sets differ between two clean make dist runs"
fi
pass "reproducible-build"

# (8) Default (no override) build prints the dev version string (D-02, D-03).
make build >/dev/null
EXPECTED_DEV="denim v$(tr -d '\n' < VERSION)-dev+$SHA ($DATE)"
ACTUAL_DEV="$(gen/denim version)"
if [ "$ACTUAL_DEV" != "$EXPECTED_DEV" ]; then
  fail "dev-version-string" "expected [$EXPECTED_DEV], got [$ACTUAL_DEV]"
fi
pass "dev-version-string"

echo "verify-dist: ALL CHECKS PASSED"
