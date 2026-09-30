#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

TAP_NAME="denim-verify/scratch"
FORMULA_NAME="${TAP_NAME}/denim"

fail() {
  echo "FAIL: $1: $2" >&2
  exit 1
}

pass() {
  echo "PASS: $1"
}

LOCAL_INSTALL=0
RELEASE_DIR=""
INSTALL_VERSION=""

if [ "$#" -eq 0 ]; then
  :
elif [ "$#" -eq 3 ] && [ "$1" = "--local-install" ]; then
  LOCAL_INSTALL=1
  RELEASE_DIR="$2"
  INSTALL_VERSION="$3"
  if ! printf '%s' "$INSTALL_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    fail "usage" "version '$INSTALL_VERSION' is not X.Y.Z"
  fi
  if [ ! -d "$RELEASE_DIR" ]; then
    fail "usage" "release-dir '$RELEASE_DIR' does not exist"
  fi
  RELEASE_DIR="$(cd "$RELEASE_DIR" && pwd)"
else
  fail "usage" "verify-formula.sh [--local-install <release-dir> <version>]"
fi

# Never risk clobbering a real, already-installed denim.
if [ "$LOCAL_INSTALL" -eq 1 ]; then
  if brew list --formula 2>/dev/null | grep -qx "denim"; then
    fail "local-install-guard" "a 'denim' formula is already installed from some tap; refusing to risk clobbering a real install"
  fi
fi

INSTALLED_BY_US=0

# Cleanup runs on pass or fail, and only ever removes what THIS run installed.
cleanup() {
  if [ "$INSTALLED_BY_US" -eq 1 ]; then
    brew uninstall --force "${FORMULA_NAME}" >/dev/null 2>&1 || true
  fi
  if brew tap 2>/dev/null | grep -qx "${TAP_NAME}"; then
    brew untap "${TAP_NAME}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if brew tap 2>/dev/null | grep -qx "${TAP_NAME}"; then
  brew untap "${TAP_NAME}" >/dev/null 2>&1 || true
fi
brew tap-new --no-git "${TAP_NAME}"

TAP_FORMULA_DIR="$(brew --repository "${TAP_NAME}")/Formula"
mkdir -p "$TAP_FORMULA_DIR"
cp "Formula/denim.rb" "${TAP_FORMULA_DIR}/denim.rb"

# Tap-qualified name only — never a path (brew audit [path] is disabled) and
# never --new/--online here (the release URLs do not exist yet).
brew style "${FORMULA_NAME}"
pass "brew-style"

brew audit --strict "${FORMULA_NAME}"
pass "brew-audit-strict"

if [ "$LOCAL_INSTALL" -eq 1 ]; then
  FORMULA_FILE="${TAP_FORMULA_DIR}/denim.rb"

  # file:// URLs defeat Homebrew's github-releases version auto-detection, so
  # this scratch-only copy gets an explicit version line + file:// URLs.
  # The committed Formula/denim.rb (outside the tap) is never touched here.
  TMP_FORMULA="$(mktemp)"
  awk -v ver="$INSTALL_VERSION" -v dir="$RELEASE_DIR" '
    /^  license "MIT"$/ {
      print
      print "  version \"" ver "\""
      next
    }
    /^      url "/ {
      if ($0 ~ /darwin_arm64/) { print "      url \"file://" dir "/denim_darwin_arm64.tar.gz\""; next }
      if ($0 ~ /darwin_amd64/) { print "      url \"file://" dir "/denim_darwin_amd64.tar.gz\""; next }
      if ($0 ~ /linux_arm64/)  { print "      url \"file://" dir "/denim_linux_arm64.tar.gz\""; next }
      if ($0 ~ /linux_amd64/)  { print "      url \"file://" dir "/denim_linux_amd64.tar.gz\""; next }
      print
      next
    }
    { print }
  ' "$FORMULA_FILE" > "$TMP_FORMULA"
  mv "$TMP_FORMULA" "$FORMULA_FILE"

  # Every `url "..."` line must have been substituted to file://; a surviving
  # https:// release URL means the awk substitution above missed an asset name
  # (e.g. a renamed archive) and would otherwise fail later, opaquely, at
  # `brew install`'s download step instead of here with a clear message.
  # Match only `url "` lines — the `homepage "https://..."` line is expected
  # to stay a github.com URL and must not trip this guard.
  LEFTOVER_URLS="$(grep -E '^[[:space:]]*url "https://' "$FORMULA_FILE" || true)"
  if [ -n "$LEFTOVER_URLS" ]; then
    fail "local-install" "unsubstituted release URL(s) survived the file:// substitution:
$LEFTOVER_URLS"
  fi

  brew install "${FORMULA_NAME}"
  INSTALLED_BY_US=1

  brew test "${FORMULA_NAME}"

  INSTALLED_BIN="$(brew --prefix)/bin/denim"
  if [ ! -x "$INSTALLED_BIN" ]; then
    fail "local-install" "installed binary not found at $INSTALLED_BIN"
  fi
  ACTUAL_VERSION_OUT="$("$INSTALLED_BIN" version)"
  case "$ACTUAL_VERSION_OUT" in
    "denim v${INSTALL_VERSION} ("*) ;;
    *) fail "local-install" "expected output starting with 'denim v${INSTALL_VERSION} (', got '$ACTUAL_VERSION_OUT'" ;;
  esac
  pass "local-install-brew-test"
fi

echo "verify-formula: ALL CHECKS PASSED"
