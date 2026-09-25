#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

DIST_DIR="gen/dist"
RELEASE_DIR="gen/release"

# Require all five gen/dist binaries to exist before doing anything else.
for name in denim_darwin_amd64 denim_darwin_arm64 denim_linux_amd64 denim_linux_arm64 denim_windows_amd64.exe; do
  if [ ! -f "$DIST_DIR/$name" ]; then
    echo "package-release: missing $DIST_DIR/$name (run make dist first)" >&2
    exit 1
  fi
done

# Pick GNU tar: bsdtar (macOS default) rejects --mtime.
if tar --version 2>/dev/null | grep -q GNU; then
  TAR_BIN="tar"
elif command -v gtar >/dev/null 2>&1; then
  TAR_BIN="gtar"
else
  echo "package-release: GNU tar required (brew install gnu-tar)" >&2
  exit 1
fi

if command -v shasum >/dev/null 2>&1; then
  SHA256() { shasum -a 256 "$@"; }
else
  SHA256() { sha256sum "$@"; }
fi

MTIME="$(git log -1 --format=%cI)"

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

for pair in darwin_amd64 darwin_arm64 linux_amd64 linux_arm64; do
  cp "$DIST_DIR/denim_${pair}" "$RELEASE_DIR/denim"
  chmod 0755 "$RELEASE_DIR/denim"
  # Compress via a separate `gzip -n` rather than tar's own -z: tar's --mtime
  # only stamps the archive MEMBER's timestamp, but its -z shortcut still lets
  # gzip stamp the *outer* gzip header's MTIME field with the current wall
  # clock, which alone defeats reproducibility across two otherwise-identical
  # runs. `gzip -n` (--no-name) omits both the original filename and the
  # timestamp from that header.
  "$TAR_BIN" -C "$RELEASE_DIR" --sort=name --mtime="$MTIME" --owner=0 --group=0 --numeric-owner \
    -cf - denim | gzip -n > "$RELEASE_DIR/denim_${pair}.tar.gz"
  rm "$RELEASE_DIR/denim"
done

cp "$DIST_DIR/denim_windows_amd64.exe" "$RELEASE_DIR/denim.exe"
(cd "$RELEASE_DIR" && zip -q -X denim_windows_amd64.zip denim.exe)
rm "$RELEASE_DIR/denim.exe"

(
  cd "$RELEASE_DIR"
  SHA256 denim_darwin_amd64.tar.gz denim_darwin_arm64.tar.gz denim_linux_amd64.tar.gz denim_linux_arm64.tar.gz denim_windows_amd64.zip > SHA256SUMS
)

echo "package-release: wrote gen/release (5 archives + SHA256SUMS)"
