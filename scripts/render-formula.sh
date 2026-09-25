#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "render-formula: $1" >&2
  exit 2
}

if [ "$#" -ne 5 ]; then
  fail "usage: render-formula.sh <version> <owner/repo> <server-url> <sha256sums-file> <output-file>"
fi

VERSION="$1"
OWNER_REPO="$2"
SERVER_URL="$3"
SUMS_FILE="$4"
OUTPUT_FILE="$5"

if ! printf '%s' "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  fail "version '$VERSION' is not X.Y.Z"
fi

if ! printf '%s' "$OWNER_REPO" | grep -qE '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'; then
  fail "owner/repo '$OWNER_REPO' is not OWNER/REPO"
fi

if ! printf '%s' "$SERVER_URL" | grep -qE '^https://[A-Za-z0-9.-]+(:[0-9]+)?$'; then
  fail "server-url '$SERVER_URL' is not https://host[:port]"
fi

if [ ! -f "$SUMS_FILE" ]; then
  fail "sha256sums file '$SUMS_FILE' not found"
fi

# Look up the sha256 for a given archive name in $SUMS_FILE. Requires exactly
# one matching line and a 64-char lowercase hex hash. Fails (exit 2) otherwise.
get_hash() {
  local fname="$1"
  local matching_lines
  matching_lines="$(awk -v f="$fname" '$2 == f { print }' "$SUMS_FILE")"
  local count=0
  if [ -n "$matching_lines" ]; then
    count="$(printf '%s\n' "$matching_lines" | wc -l | tr -d ' ')"
  fi
  if [ "$count" -ne 1 ]; then
    fail "sha256sums file has $count line(s) for $fname, expected exactly 1"
  fi
  local hash
  hash="$(printf '%s\n' "$matching_lines" | awk '{print $1}')"
  if ! printf '%s' "$hash" | grep -qE '^[0-9a-f]{64}$'; then
    fail "hash for $fname is not 64 lowercase hex chars: $hash"
  fi
  printf '%s' "$hash"
}

SHA_DARWIN_ARM64="$(get_hash denim_darwin_arm64.tar.gz)"
SHA_DARWIN_AMD64="$(get_hash denim_darwin_amd64.tar.gz)"
SHA_LINUX_ARM64="$(get_hash denim_linux_arm64.tar.gz)"
SHA_LINUX_AMD64="$(get_hash denim_linux_amd64.tar.gz)"

BASE_URL="${SERVER_URL}/${OWNER_REPO}/releases/download/v${VERSION}"

# Build in a temp file in the output's directory, then mv into place — no
# half-written formula is ever visible at OUTPUT_FILE.
OUT_DIR="$(dirname "$OUTPUT_FILE")"
if [ ! -d "$OUT_DIR" ]; then
  fail "output directory '$OUT_DIR' does not exist"
fi
TMP_FILE="$(mktemp "${OUT_DIR}/.denim-formula.XXXXXX")"
trap 'rm -f "$TMP_FILE"' EXIT
# mktemp defaults to mode 600; a formula file must be world-readable like any
# other tracked source file (brew style flags a non-readable formula).
chmod 0644 "$TMP_FILE"

cat > "$TMP_FILE" <<EOF
# This file is updated automatically by the release workflow.
class Denim < Formula
  desc "Persistent BlueJeans, Zoom, Slack huddle and Hangouts room opener"
  homepage "${SERVER_URL}/${OWNER_REPO}"
  license "MIT"

  on_macos do
    on_arm do
      url "${BASE_URL}/denim_darwin_arm64.tar.gz"
      sha256 "${SHA_DARWIN_ARM64}"
    end
    on_intel do
      url "${BASE_URL}/denim_darwin_amd64.tar.gz"
      sha256 "${SHA_DARWIN_AMD64}"
    end
  end

  on_linux do
    on_arm do
      url "${BASE_URL}/denim_linux_arm64.tar.gz"
      sha256 "${SHA_LINUX_ARM64}"
    end
    on_intel do
      url "${BASE_URL}/denim_linux_amd64.tar.gz"
      sha256 "${SHA_LINUX_AMD64}"
    end
  end

  def install
    bin.install "denim"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/denim version")
  end
end
EOF

mv "$TMP_FILE" "$OUTPUT_FILE"
trap - EXIT

echo "render-formula: wrote $OUTPUT_FILE"
