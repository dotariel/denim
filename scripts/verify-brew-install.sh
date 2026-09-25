#!/usr/bin/env bash
set -euo pipefail

# verify-brew-install.sh <version> [platform ...]
#
# Verifies a published release installs via the fully-qualified Homebrew tap
# name inside the official `homebrew/brew` Docker image, for one or more
# linux/<arch> platforms (default: linux/amd64 linux/arm64). Never publishes
# anything — install + brew test + a version-string check only.
#
# NOTE: the first install in a fresh container pulls the gcc/binutils
# dependency chain Linuxbrew needs — this can take a few minutes per
# platform on a cold Docker image cache.

fail() {
  echo "verify-brew-install: $1" >&2
  exit 2
}

if [ "$#" -lt 1 ]; then
  fail "usage: verify-brew-install.sh <version> [platform ...]"
fi

VERSION="$1"
shift
if ! printf '%s' "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  fail "version '$VERSION' is not X.Y.Z"
fi

PLATFORMS=("$@")
if [ "${#PLATFORMS[@]}" -eq 0 ]; then
  PLATFORMS=(linux/amd64 linux/arm64)
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -n "${TAP:-}" ]; then
  if ! printf '%s' "$TAP" | grep -qE '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'; then
    fail "TAP '$TAP' is not OWNER/REPO"
  fi
else
  origin_url="$(git -C "$REPO_ROOT" remote get-url origin)"
  case "$origin_url" in
    git@*:*) TAP="${origin_url#*:}" ;;
    https://*|http://*) TAP="${origin_url#*://*/}" ;;
    *) fail "cannot parse owner/repo from origin url '$origin_url'; set TAP=owner/repo explicitly" ;;
  esac
  TAP="${TAP%.git}"
  if ! printf '%s' "$TAP" | grep -qE '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'; then
    fail "parsed TAP '$TAP' from origin url '$origin_url' is not OWNER/REPO; set TAP=owner/repo explicitly"
  fi
fi

TAP_URL="${TAP_URL:-https://github.com/${TAP}}"

if ! docker info >/dev/null 2>&1; then
  fail "docker is not available/running — start Docker Desktop (or the docker daemon) and retry"
fi

# Container-side script: $VERSION/$TAP/$TAP_URL below are intentionally
# unexpanded here (single-quoted heredoc) — they resolve against the
# container's own environment (passed with -e, never spliced into this
# string) when bash -c runs them inside the official Homebrew image below.
read -r -d '' CONTAINER_SCRIPT <<'INNER_EOF' || true
set -euo pipefail
brew tap "$TAP" "$TAP_URL"
brew install "$TAP/denim"
brew test "$TAP/denim"
INSTALLED_BIN="$(brew --prefix)/bin/denim"
ACTUAL_VERSION_OUT="$("$INSTALLED_BIN" version)"
case "$ACTUAL_VERSION_OUT" in
  denim\ v"$VERSION"\ \(*) ;;
  *)
    echo "verify-brew-install: expected output starting with denim v$VERSION (, got $ACTUAL_VERSION_OUT" >&2
    exit 1
    ;;
esac
INNER_EOF

for platform in "${PLATFORMS[@]}"; do
  docker run --rm --platform "$platform" \
    -e VERSION="$VERSION" \
    -e TAP="$TAP" \
    -e TAP_URL="$TAP_URL" \
    homebrew/brew:latest \
    bash -c "$CONTAINER_SCRIPT"
  echo "PASS: install:${platform}"
done

echo "verify-brew-install: ALL PLATFORMS PASSED"
