#!/usr/bin/env bash
set -euo pipefail

# test-release.sh — the executable spec for scripts/release.sh.
#
# Builds a throwaway fixture per case under a mktemp dir (removed by an EXIT
# trap): a bare `remote.git`, a `work` clone seeded from the CURRENT source
# working tree (tracked plus untracked-not-ignored files), and a fake `gh`
# implementing exactly the forms release.sh uses. Never touches GitHub — every
# fixture asserts its own `origin` points at the local bare repo before running
# anything.
#
# Usage: scripts/test-release.sh [case ...]   (default: run every case)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RELEASE_SH="$REPO_ROOT/scripts/release.sh"

FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/denim-test-release.XXXXXX")"
cleanup() { rm -rf "$FIXTURE_ROOT"; }
trap cleanup EXIT

# Some developer machines set a global core.hooksPath (e.g. a commit-msg hook
# requiring a JIRA-shaped token) that would otherwise fire inside every
# throwaway fixture repo below. Point every fixture repo at an empty hooks
# dir so fixture commits behave like a real CI runner (which has no such
# hook) — this does not touch hook behavior for the actual source repo.
EMPTY_HOOKS_DIR="$FIXTURE_ROOT/empty-hooks"
mkdir -p "$EMPTY_HOOKS_DIR"

fail_case() {
  echo "FAIL: $1: $2" >&2
  exit 1
}

pass_case() {
  echo "PASS: $1"
}

# Globals set by setup_fixture, read by run_release and the case bodies.
CASE_DIR=""
REMOTE_GIT=""
WORK=""
FAKE_GH_DIR=""
FAKE_BIN=""

write_fake_gh() {
  local bin_dir="$1"
  cat > "$bin_dir/gh" <<'FAKE_GH_EOF'
#!/usr/bin/env bash
set -euo pipefail
: "${FAKE_GH_DIR:?FAKE_GH_DIR required}"
: "${FAKE_GH_REMOTE:?FAKE_GH_REMOTE required}"

printf '%s\n' "$*" >> "$FAKE_GH_DIR/calls.log"

if [ "$#" -lt 2 ]; then
  echo "fake gh: unsupported invocation: $*" >&2
  exit 99
fi

top="$1"; sub="$2"; shift 2

case "$top $sub" in
  "release view")
    tag="${1:?fake gh: release view requires <tag>}"; shift
    if [ "${FAKE_GH_VIEW_ERROR:-0}" = "1" ]; then
      echo "HTTP 502: Bad Gateway" >&2
      exit 1
    fi
    state_file="$FAKE_GH_DIR/${tag}.state"
    if [ ! -f "$state_file" ]; then
      echo "release not found" >&2
      exit 1
    fi
    state="$(cat "$state_file")"
    case "$state" in
      draft) echo "true" ;;
      published) echo "false" ;;
      *) echo "fake gh: unknown state '$state' for $tag" >&2; exit 1 ;;
    esac
    ;;
  "release delete")
    tag="${1:?fake gh: release delete requires <tag>}"; shift
    rm -f "$FAKE_GH_DIR/${tag}.state"
    rm -rf "$FAKE_GH_DIR/${tag}"
    git --git-dir="$FAKE_GH_REMOTE" tag -d "$tag" >/dev/null 2>&1 || true
    ;;
  "release create")
    tag="${1:?fake gh: release create requires <tag>}"; shift
    target=""
    files=()
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --repo) shift 2 ;;
        --target) target="$2"; shift 2 ;;
        --title) shift 2 ;;
        --generate-notes) shift 1 ;;
        *) files+=("$1"); shift 1 ;;
      esac
    done
    mkdir -p "$FAKE_GH_DIR/${tag}"
    echo "draft" > "$FAKE_GH_DIR/${tag}.state"
    for f in "${files[@]}"; do
      cp "$f" "$FAKE_GH_DIR/${tag}/"
    done
    if [ "${FAKE_GH_CREATE_FAIL_AFTER_DRAFT:-0}" = "1" ]; then
      exit 1
    fi
    git --git-dir="$FAKE_GH_REMOTE" tag "$tag" "$target"
    echo "published" > "$FAKE_GH_DIR/${tag}.state"
    ;;
  "release download")
    tag="${1:?fake gh: release download requires <tag>}"; shift
    dir=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --repo) shift 2 ;;
        --dir) dir="$2"; shift 2 ;;
        *) shift 1 ;;
      esac
    done
    mkdir -p "$dir"
    cp "$FAKE_GH_DIR/${tag}"/* "$dir/"
    ;;
  *)
    echo "fake gh: unsupported invocation: $top $sub $*" >&2
    exit 99
    ;;
esac
FAKE_GH_EOF
  chmod 0755 "$bin_dir/gh"
}

# setup_fixture <case-name> — build a fresh remote.git + work clone under
# FIXTURE_ROOT/<case-name>, seeded from the CURRENT source tree, with tags
# v0.1.9 and v0.1.10 pushed. Sets CASE_DIR/REMOTE_GIT/WORK/FAKE_GH_DIR/FAKE_BIN.
setup_fixture() {
  local case_name="$1"
  local case_dir="$FIXTURE_ROOT/$case_name"
  mkdir -p "$case_dir"

  local remote_git="$case_dir/remote.git"
  local work="$case_dir/work"
  local fake_gh_dir="$case_dir/fake-gh-state"
  local fake_bin="$case_dir/bin"

  git init -q --bare "$remote_git"
  mkdir -p "$fake_gh_dir" "$fake_bin"
  write_fake_gh "$fake_bin"

  mkdir -p "$work"
  while IFS= read -r -d '' f; do
    mkdir -p "$work/$(dirname "$f")"
    cp -p "$REPO_ROOT/$f" "$work/$f"
  done < <(cd "$REPO_ROOT" && { git ls-files -z; git ls-files -z --others --exclude-standard; })

  (
    cd "$work"
    git init -q -b master
    git config core.hooksPath "$EMPTY_HOOKS_DIR"
    git config user.name "denim-test-fixture"
    git config user.email "fixture@example.com"
    git add -A
    git commit -q -m "fixture: snapshot of source tree"
    git remote add origin "$remote_git"
    git push -q origin master
    git tag v0.1.9
    git tag v0.1.10
    git push -q origin v0.1.9 v0.1.10
  )

  local origin_url
  origin_url="$(git -C "$work" remote get-url origin)"
  if [ "$origin_url" != "$remote_git" ]; then
    echo "test-release: ABORT — fixture work dir origin is '$origin_url', expected '$remote_git'; refusing to run (harness must never reach GitHub)" >&2
    exit 1
  fi

  CASE_DIR="$case_dir"
  REMOTE_GIT="$remote_git"
  WORK="$work"
  FAKE_GH_DIR="$fake_gh_dir"
  FAKE_BIN="$fake_bin"
}

# run_release [VAR=val ...] — run `release.sh run` inside $WORK against the
# fake gh, with the fixed acme/denim-test identity (proves D-10: nothing in
# release.sh names the real esumerfd owner).
run_release() {
  (
    cd "$WORK"
    env "$@" \
      GH="$FAKE_BIN/gh" \
      FAKE_GH_DIR="$FAKE_GH_DIR" \
      FAKE_GH_REMOTE="$REMOTE_GIT" \
      GITHUB_REPOSITORY="acme/denim-test" \
      GITHUB_SERVER_URL="https://github.com" \
      RELEASE_BRANCH="master" \
      GITHUB_OUTPUT="$CASE_DIR/github_output" \
      REMOTE="origin" \
      "$RELEASE_SH" run
  )
}

case_happy_path() {
  local name="happy-path"
  setup_fixture "$name"
  local pre_sha
  pre_sha="$(git -C "$WORK" rev-parse HEAD)"

  local out status
  set +e
  out="$(run_release INPUT_VERSION=0.2.0 2>&1)"
  status=$?
  set -e
  [ "$status" -eq 0 ] || fail_case "$name" "release.sh run exited $status: $out"

  local state
  state="$(cat "$FAKE_GH_DIR/v0.2.0.state" 2>/dev/null || true)"
  [ "$state" = "published" ] || fail_case "$name" "expected fake release v0.2.0 published, got '$state'"

  local asset_count
  asset_count="$(find "$FAKE_GH_DIR/v0.2.0" -type f | wc -l | tr -d ' ')"
  [ "$asset_count" -eq 6 ] || fail_case "$name" "expected 6 assets in fake release, got $asset_count"

  grep -q -- '--generate-notes' "$FAKE_GH_DIR/calls.log" || fail_case "$name" "calls.log missing --generate-notes"
  grep -q -- "--target $pre_sha" "$FAKE_GH_DIR/calls.log" || fail_case "$name" "calls.log create --target does not match pre-release master sha $pre_sha"

  local tag_sha
  tag_sha="$(git --git-dir="$REMOTE_GIT" rev-parse 'v0.2.0^{commit}' 2>/dev/null || true)"
  [ "$tag_sha" = "$pre_sha" ] || fail_case "$name" "remote.git tag v0.2.0 points at '$tag_sha', expected '$pre_sha'"

  local new_commit_count
  new_commit_count="$(git --git-dir="$REMOTE_GIT" rev-list --count "$pre_sha..master")"
  [ "$new_commit_count" -eq 1 ] || fail_case "$name" "expected remote master to advance by exactly 1 commit, advanced by $new_commit_count"

  local new_master_sha
  new_master_sha="$(git --git-dir="$REMOTE_GIT" rev-parse master)"
  local author
  author="$(git --git-dir="$REMOTE_GIT" log -1 --format='%an <%ae>' "$new_master_sha")"
  [ "$author" = "github-actions[bot] <github-actions[bot]@users.noreply.github.com>" ] || fail_case "$name" "unexpected formula commit author: $author"

  local changed_files
  changed_files="$(git --git-dir="$REMOTE_GIT" diff-tree --no-commit-id --name-only -r "$new_master_sha")"
  [ "$changed_files" = "Formula/denim.rb" ] || fail_case "$name" "expected only Formula/denim.rb changed on the formula commit, got: $changed_files"

  local formula
  formula="$(git --git-dir="$REMOTE_GIT" show "master:Formula/denim.rb")"
  local url_count
  url_count="$(printf '%s\n' "$formula" | grep -cE 'https://github\.com/acme/denim-test/releases/download/v0\.2\.0/denim_[a-z]+_[a-z0-9]+\.tar\.gz')"
  [ "$url_count" -eq 4 ] || fail_case "$name" "expected 4 matching release-asset urls in formula, got $url_count"
  if printf '%s\n' "$formula" | grep -qE '^\s*version '; then
    fail_case "$name" "formula has a version stanza (must be absent)"
  fi

  while IFS=' ' read -r hash fname; do
    case "$fname" in
      *.tar.gz)
        printf '%s\n' "$formula" | grep -qF "sha256 \"$hash\"" || fail_case "$name" "formula missing sha256 $hash for $fname"
        ;;
    esac
  done < "$WORK/gen/release/SHA256SUMS"

  grep -qx 'version=0.2.0' "$CASE_DIR/github_output" || fail_case "$name" "GITHUB_OUTPUT missing version=0.2.0"

  local refs expected_refs
  refs="$(git --git-dir="$REMOTE_GIT" for-each-ref --format='%(refname)' | sort)"
  expected_refs="$(printf 'refs/heads/master\nrefs/tags/v0.1.10\nrefs/tags/v0.1.9\nrefs/tags/v0.2.0\n' | sort)"
  [ "$refs" = "$expected_refs" ] || fail_case "$name" "unexpected refs in remote.git:
$refs"

  pass_case "$name"
}

case_next_version_auto() {
  local name="next-version-auto"
  setup_fixture "$name"

  (
    cd "$WORK"
    git tag v0.1.10-rc1
    git tag latest
    git push -q origin v0.1.10-rc1 latest
  )

  local out status
  set +e
  out="$(cd "$WORK" && REMOTE=origin "$RELEASE_SH" next-version "")"
  status=$?
  set -e
  [ "$status" -eq 0 ] || fail_case "$name" "next-version '' exited $status: $out"
  [ "$out" = "0.1.11" ] || fail_case "$name" "expected 0.1.11 with v0.1.9/v0.1.10/v0.1.10-rc1/latest present, got '$out'"

  local empty_remote empty_work
  empty_remote="$FIXTURE_ROOT/${name}-empty-remote.git"
  empty_work="$FIXTURE_ROOT/${name}-empty-work"
  git init -q --bare "$empty_remote"
  mkdir -p "$empty_work"
  (
    cd "$empty_work"
    git init -q -b master
    git config core.hooksPath "$EMPTY_HOOKS_DIR"
    git config user.name "denim-test-fixture"
    git config user.email "fixture@example.com"
    : > README-empty
    git add -A
    git commit -q -m "empty fixture, no tags"
    git remote add origin "$empty_remote"
    git push -q origin master
  )
  set +e
  ( cd "$empty_work" && REMOTE=origin "$RELEASE_SH" next-version "" >/dev/null 2>&1 )
  status=$?
  set -e
  [ "$status" -ne 0 ] || fail_case "$name" "next-version '' unexpectedly succeeded with no v* tags on the remote"

  pass_case "$name"
}

case_invalid_input() {
  local name="invalid-input"

  local scratch bad status
  scratch="$FIXTURE_ROOT/${name}-scratch"
  mkdir -p "$scratch"
  for bad in "v0.2.0" "0.2" "0.2.0-rc1" "0.2.0;touch pwned" '$(touch pwned)'; do
    set +e
    ( cd "$scratch" && "$RELEASE_SH" next-version "$bad" >/dev/null 2>&1 )
    status=$?
    set -e
    [ "$status" -eq 2 ] || fail_case "$name" "next-version '$bad' exited $status, expected 2"
  done
  [ ! -e "$scratch/pwned" ] || fail_case "$name" "command injection: a 'pwned' file was created by a next-version input"

  setup_fixture "$name"
  local out
  set +e
  out="$(run_release INPUT_VERSION=v0.2.0 2>&1)"
  status=$?
  set -e
  [ "$status" -ne 0 ] || fail_case "$name" "run with INPUT_VERSION=v0.2.0 unexpectedly succeeded"
  if [ -s "$FAKE_GH_DIR/calls.log" ]; then
    fail_case "$name" "calls.log has entries for a rejected version input: $(cat "$FAKE_GH_DIR/calls.log")"
  fi
  [ ! -d "$WORK/gen/release" ] || fail_case "$name" "gen/release exists in work after a rejected version input"

  pass_case "$name"
}

ALL_CASES=(happy-path next-version-auto invalid-input)

main() {
  local requested=("$@")
  if [ "${#requested[@]}" -eq 0 ]; then
    requested=("${ALL_CASES[@]}")
  fi
  local c
  for c in "${requested[@]}"; do
    case "$c" in
      happy-path) case_happy_path ;;
      next-version-auto) case_next_version_auto ;;
      invalid-input) case_invalid_input ;;
      *) echo "test-release: unknown case '$c'" >&2; exit 1 ;;
    esac
  done
  echo "test-release: ALL CASES PASSED"
}

main "$@"
