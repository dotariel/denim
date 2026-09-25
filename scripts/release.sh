#!/usr/bin/env bash
set -euo pipefail

# release.sh — drives the release.yml workflow_dispatch pipeline.
#
# Subcommands:
#   next-version [input]      print the version to release (validated input, or
#                              latest remote vX.Y.Z tag + 1 patch)
#   guard <tag>                fail the run before any build work if <tag> is
#                              already released, tagged without a release, or in
#                              an unknown state
#   publish-formula <tag> <branch>
#                              commit and push the rendered Formula/denim.rb
#   run                        the whole pipeline: version -> branch check ->
#                              guard -> build -> package -> publish -> verify
#                              downloaded bytes -> render formula -> push
#
# Environment:
#   GH                 gh binary to invoke (default: gh) — every gh call goes
#                      through "$GH" so tests can point it at a fake.
#   REMOTE              git remote name to read tags from / push to (default: origin)
#   GITHUB_REPOSITORY   owner/repo, required by guard/run (no owner hard-coded here)
#   GITHUB_SERVER_URL   default https://github.com
#   RELEASE_BRANCH      branch run must be on and must push to; required by run
#   INPUT_VERSION       optional workflow_dispatch input, consumed by run
#   GITHUB_OUTPUT       optional; if set, run appends version=<version>

GH="${GH:-gh}"
REMOTE="${REMOTE:-origin}"
GITHUB_SERVER_URL="${GITHUB_SERVER_URL:-https://github.com}"

usage() {
  echo "usage: release.sh {next-version [input]|guard <tag>|publish-formula <tag> <branch>|run}" >&2
  exit 2
}

# cmd_next_version [input] — print the version to use for this release.
cmd_next_version() {
  local input="${1-}"

  if [ -n "$input" ]; then
    if ! printf '%s' "$input" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
      echo "::error::version input '$input' is not X.Y.Z" >&2
      exit 2
    fi
    printf '%s\n' "$input"
    return 0
  fi

  local tags
  if ! tags="$(git ls-remote --tags --refs "$REMOTE" 2>&1)"; then
    echo "::error::git ls-remote --tags --refs $REMOTE failed: $tags" >&2
    exit 1
  fi

  local versions
  versions="$(printf '%s\n' "$tags" | awk '{print $2}' | grep -E '^refs/tags/v[0-9]+\.[0-9]+\.[0-9]+$' | sed 's#^refs/tags/v##')"
  if [ -z "$versions" ]; then
    echo "::error::no v<X.Y.Z> tags found on $REMOTE and no version input given" >&2
    exit 1
  fi

  local highest
  highest="$(printf '%s\n' "$versions" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)"

  local major minor patch
  IFS='.' read -r major minor patch <<< "$highest"
  printf '%s.%s.%s\n' "$major" "$minor" "$((patch + 1))"
}

# cmd_guard <tag> — fail closed unless there is nothing published or tagged yet
# for <tag>. Tracer shape (Task 1): any existing release (draft or published),
# any existing tag, or any unexpected gh/git error stops the run.
cmd_guard() {
  local tag="${1:?guard requires <tag>}"
  : "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY required}"

  local view_out view_status
  set +e
  view_out="$("$GH" release view "$tag" --repo "$GITHUB_REPOSITORY" --json isDraft --jq .isDraft 2>&1)"
  view_status=$?
  set -e

  if [ "$view_status" -eq 0 ]; then
    echo "::error::$tag already has a release (draft or published)" >&2
    exit 1
  fi
  if ! printf '%s' "$view_out" | grep -q 'release not found'; then
    echo "::error::cannot determine release state for $tag: $view_out" >&2
    exit 1
  fi

  if git ls-remote --exit-code --tags "$REMOTE" "refs/tags/$tag" >/dev/null 2>&1; then
    echo "::error::tag $tag exists without a release" >&2
    exit 1
  fi
}

# cmd_publish_formula <tag> <branch> — commit Formula/denim.rb (must already be
# rendered/changed on disk) as github-actions[bot] and push it. Tracer shape
# (Task 1): single push attempt, no retry, no force option of any kind.
cmd_publish_formula() {
  local tag="${1:?publish-formula requires <tag> <branch>}"
  local branch="${2:?publish-formula requires <tag> <branch>}"

  git config user.name "github-actions[bot]"
  git config user.email "github-actions[bot]@users.noreply.github.com"

  if git diff --quiet -- Formula/denim.rb && git diff --cached --quiet -- Formula/denim.rb; then
    echo "::error::Formula/denim.rb is unchanged; nothing to publish" >&2
    exit 1
  fi

  git add Formula/denim.rb
  git commit -q -m "chore(release): update Homebrew formula to $tag"
  git push "$REMOTE" "HEAD:refs/heads/$branch"
}

# cmd_run — the full pipeline.
cmd_run() {
  : "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY required}"
  : "${RELEASE_BRANCH:?RELEASE_BRANCH required}"

  echo "::group::version"
  local version
  version="$(cmd_next_version "${INPUT_VERSION-}")"
  local tag="v${version}"
  echo "release: computed version $version"
  echo "::endgroup::"

  echo "::group::branch-check"
  local current_branch
  current_branch="$(git rev-parse --abbrev-ref HEAD)"
  if [ "$current_branch" != "$RELEASE_BRANCH" ]; then
    echo "::error::current branch '$current_branch' is not RELEASE_BRANCH '$RELEASE_BRANCH'" >&2
    exit 1
  fi
  echo "::endgroup::"

  echo "::group::guard"
  cmd_guard "$tag"
  echo "::endgroup::"

  echo "::group::build"
  make dist BUILD_VERSION="$version"
  echo "::endgroup::"

  echo "::group::package"
  scripts/package-release.sh
  echo "::endgroup::"

  echo "::group::publish"
  local target_sha
  target_sha="$(git rev-parse HEAD)"
  "$GH" release create "$tag" \
    --repo "$GITHUB_REPOSITORY" \
    --target "$target_sha" \
    --title "$tag" \
    --generate-notes \
    gen/release/denim_darwin_amd64.tar.gz \
    gen/release/denim_darwin_arm64.tar.gz \
    gen/release/denim_linux_amd64.tar.gz \
    gen/release/denim_linux_arm64.tar.gz \
    gen/release/denim_windows_amd64.zip \
    gen/release/SHA256SUMS
  echo "::endgroup::"

  echo "::group::verify-download"
  local dl_dir
  dl_dir="$(mktemp -d)"
  "$GH" release download "$tag" --repo "$GITHUB_REPOSITORY" --dir "$dl_dir"
  if ! cmp -s "$dl_dir/SHA256SUMS" gen/release/SHA256SUMS; then
    echo "::error::downloaded SHA256SUMS differs byte-for-byte from gen/release/SHA256SUMS" >&2
    exit 1
  fi
  (
    cd "$dl_dir"
    if command -v shasum >/dev/null 2>&1; then
      shasum -a 256 -c SHA256SUMS
    else
      sha256sum -c SHA256SUMS
    fi
  )
  echo "::endgroup::"

  echo "::group::render-formula"
  scripts/render-formula.sh "$version" "$GITHUB_REPOSITORY" "$GITHUB_SERVER_URL" "$dl_dir/SHA256SUMS" Formula/denim.rb
  echo "::endgroup::"

  echo "::group::publish-formula"
  cmd_publish_formula "$tag" "$RELEASE_BRANCH"
  echo "::endgroup::"

  if [ -n "${GITHUB_OUTPUT-}" ]; then
    echo "version=$version" >> "$GITHUB_OUTPUT"
  fi

  echo "release: published $tag"
}

[ "$#" -ge 1 ] || usage

case "$1" in
  next-version)
    shift
    cmd_next_version "${1-}"
    ;;
  guard)
    shift
    [ "$#" -eq 1 ] || usage
    cmd_guard "$1"
    ;;
  publish-formula)
    shift
    [ "$#" -eq 2 ] || usage
    cmd_publish_formula "$1" "$2"
    ;;
  run)
    shift
    [ "$#" -eq 0 ] || usage
    cmd_run
    ;;
  *)
    usage
    ;;
esac
