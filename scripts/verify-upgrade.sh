#!/usr/bin/env bash
set -euo pipefail

# verify-upgrade.sh <version>
#
# D-10 upgrade check (FORM-04): against an ALREADY-TAPPED $TAP (default:
# derived from origin, same convention as verify-brew-install.sh), finds the
# highest vX.Y.Z tag strictly below <version> in the tap's own git history,
# installs that previous release (checked out at its "update Homebrew
# formula to v<prev>" commit), switches the tap back to its recorded
# branch, runs `brew upgrade`, and asserts the installed keg AND the binary
# both land on <version> at each stage. Never trusts brew's own exit code or
# an "already installed" message as proof that a version changed — every
# stage asserts the real, on-disk installed version (see RESEARCH.md
# Pitfall 1: a cold Linuxbrew can silently misresolve a tap formula's
# version, which would otherwise make `brew upgrade` conclude "nothing to
# do" and false-pass).
#
# Usage: verify-upgrade.sh <X.Y.Z>
#   TAP=owner/repo   optional; falls back to the origin-url derivation
#                    (same convention as scripts/verify-brew-install.sh)

fail() {
  echo "verify-upgrade: FAIL: $1" >&2
  exit 1
}

if [ "$#" -ne 1 ]; then
  echo "usage: verify-upgrade.sh <X.Y.Z>" >&2
  exit 2
fi

VERSION="$1"
if ! printf '%s' "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "usage: verify-upgrade.sh <X.Y.Z> — '$VERSION' is not X.Y.Z" >&2
  exit 2
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

# An auto-update mid-check would fetch the tap forward and reset our
# deliberately-detached checkout, defeating the whole install-old/upgrade
# sequence below. On Linux, a cold Linuxbrew's own auto-update is exactly
# the precondition for the version-misdetection bug this check exists to
# catch (RESEARCH.md Pitfall 1) — the caller must already have run a real,
# unsuppressed `brew update` before invoking this script there (D-23).
export HOMEBREW_NO_AUTO_UPDATE=1

TAPDIR="$(brew --repository "$TAP")"
if [ ! -d "$TAPDIR/.git" ]; then
  fail "'$TAP' is not tapped (no git checkout at $TAPDIR) — tap it before running this script"
fi

ORIGINAL_BRANCH="$(git -C "$TAPDIR" symbolic-ref --short -q HEAD || true)"
if [ -z "$ORIGINAL_BRANCH" ]; then
  fail "tap '$TAP' is detached at $(git -C "$TAPDIR" rev-parse HEAD) — expected it checked out on a branch"
fi

restore_tap_branch() {
  git -C "$TAPDIR" checkout --quiet "$ORIGINAL_BRANCH" >/dev/null 2>&1 || true
}
trap restore_tap_branch EXIT

# Highest vX.Y.Z tag strictly below VERSION, comparing numerically per
# component — same sort key as scripts/release.sh's cmd_next_version.
IFS='.' read -r WANT_MAJOR WANT_MINOR WANT_PATCH <<< "$VERSION"
PREV_VERSION="$(git -C "$TAPDIR" tag -l 'v*' \
  | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
  | sed 's/^v//' \
  | sort -t. -k1,1n -k2,2n -k3,3n \
  | awk -F. -v wmaj="$WANT_MAJOR" -v wmin="$WANT_MINOR" -v wpat="$WANT_PATCH" \
      '($1+0 < wmaj+0) || ($1+0 == wmaj+0 && $2+0 < wmin+0) || ($1+0 == wmaj+0 && $2+0 == wmin+0 && $3+0 < wpat+0)' \
  | tail -1)"

if [ -z "$PREV_VERSION" ]; then
  echo "::notice::no release before v${VERSION}; skipping upgrade check"
  echo "verify-upgrade: SKIP: no release before v${VERSION}"
  exit 0
fi

# Newest commit touching Formula/denim.rb whose subject is EXACTLY
# "chore(release): update Homebrew formula to v<prev>" — a whole-subject
# comparison, never a substring/prefix match, so a search for v0.2.1 can
# never match a commit actually meant for v0.2.10.
#
# awk deliberately has NO `exit` after the first match: an early exit would
# close awk's read end while `git log` may still be writing, and under
# `set -o pipefail` the resulting SIGPIPE (128+13=141) on git log becomes
# this whole command substitution's exit status even though awk itself
# succeeded — tripping `set -e` and killing the script before the
# `[ -z "$PREV_SHA" ]` check below ever runs. Reading to EOF and taking
# just the first line in bash afterward (git log lists newest-first, so
# the first match is already the newest) avoids the race entirely.
EXPECTED_SUBJECT="chore(release): update Homebrew formula to v${PREV_VERSION}"
PREV_SHA_MATCHES="$(git -C "$TAPDIR" log --format='%H%x09%s' -- Formula/denim.rb \
  | awk -F'\t' -v want="$EXPECTED_SUBJECT" '$2 == want { print $1 }')"
PREV_SHA="${PREV_SHA_MATCHES%%$'\n'*}"
if [ -z "$PREV_SHA" ]; then
  fail "no commit touching Formula/denim.rb has subject '${EXPECTED_SUBJECT}'"
fi

# Two-stage assertion: the linked keg's basename (Pitfall 1 corrupts this to
# a placeholder like "64") AND the binary's own printed version must both
# match — brew's exit code / "already installed" text is never trusted.
assert_version() {
  local expected="$1" resolved_target actual_keg actual_bin_out

  resolved_target="$(readlink "$(brew --prefix)/opt/denim" 2>/dev/null || true)"
  if [ -n "$resolved_target" ]; then
    actual_keg="$(basename "$resolved_target")"
  else
    actual_keg=""
  fi
  actual_bin_out="$("$(brew --prefix)/bin/denim" version 2>&1 || true)"

  case "$actual_bin_out" in
    "denim v${expected} ("*)
      if [ "$actual_keg" = "$expected" ]; then
        return 0
      fi
      ;;
  esac

  fail "expected linked keg '${expected}' and binary output starting 'denim v${expected} (', got linked keg '${actual_keg:-<none>}' and binary output '${actual_bin_out:-<none>}'"
}

# Idempotency: uninstall any existing denim first so a re-run always starts
# clean — this, plus the EXIT trap above restoring the tap's branch, is what
# makes back-to-back invocations of this script both pass. Unconditional and
# tolerant of "nothing to uninstall" (`|| true`) rather than gating on a
# `brew list --formula | grep` existence check first: piping brew's full,
# large formula list into `grep -q` lets grep exit after its first match
# while brew is still writing, so brew is killed by SIGPIPE — under
# `set -o pipefail` that non-zero SIGPIPE exit status (141) becomes the
# pipeline's own status even though grep itself matched, making the `if`
# wrongly read as "not installed" and silently skip the uninstall.
brew uninstall --force "$TAP/denim" || true

git -C "$TAPDIR" checkout --quiet "$PREV_SHA"
brew install "$TAP/denim"
assert_version "$PREV_VERSION"

git -C "$TAPDIR" checkout --quiet "$ORIGINAL_BRANCH"
brew upgrade "$TAP/denim"
assert_version "$VERSION"

echo "verify-upgrade: PASS: v${PREV_VERSION} -> v${VERSION}"
