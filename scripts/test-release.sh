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

file_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1"
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
  # A developer machine's global core.hooksPath (see EMPTY_HOOKS_DIR above)
  # would otherwise shadow this bare repo's own hooks/ directory too — reset
  # it to the repo's real hooks dir so a fixture-installed pre-receive hook
  # (push-fails-twice) actually fires.
  git -C "$remote_git" config core.hooksPath "$remote_git/hooks"
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

# ensure_happy_path_done — runs the happy-path fixture + release exactly once
# per test-release.sh invocation (memoized), so `published-refuses` can reuse
# happy-path's fixture state per its spec ("after happy-path's fixture
# state, re-run with the same version") regardless of which cases were
# requested on the command line. Restores CASE_DIR/REMOTE_GIT/WORK/
# FAKE_GH_DIR/FAKE_BIN to the happy-path fixture on every call.
HAPPY_PATH_DONE=0
HP_CASE_DIR="" HP_REMOTE_GIT="" HP_WORK="" HP_FAKE_GH_DIR="" HP_FAKE_BIN="" HP_PRE_SHA=""

ensure_happy_path_done() {
  if [ "$HAPPY_PATH_DONE" -eq 1 ]; then
    CASE_DIR="$HP_CASE_DIR"; REMOTE_GIT="$HP_REMOTE_GIT"; WORK="$HP_WORK"
    FAKE_GH_DIR="$HP_FAKE_GH_DIR"; FAKE_BIN="$HP_FAKE_BIN"
    return 0
  fi

  setup_fixture "happy-path"
  HP_PRE_SHA="$(git -C "$WORK" rev-parse HEAD)"

  local out status
  set +e
  out="$(run_release INPUT_VERSION=0.2.0 2>&1)"
  status=$?
  set -e
  [ "$status" -eq 0 ] || fail_case "happy-path" "release.sh run exited $status: $out"

  HP_CASE_DIR="$CASE_DIR"; HP_REMOTE_GIT="$REMOTE_GIT"; HP_WORK="$WORK"
  HP_FAKE_GH_DIR="$FAKE_GH_DIR"; HP_FAKE_BIN="$FAKE_BIN"
  HAPPY_PATH_DONE=1
}

case_happy_path() {
  local name="happy-path"
  ensure_happy_path_done
  local pre_sha="$HP_PRE_SHA"

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

case_published_refuses() {
  local name="published-refuses"
  ensure_happy_path_done

  local pre_master_sha
  pre_master_sha="$(git --git-dir="$REMOTE_GIT" rev-parse master)"
  local pre_create_count
  pre_create_count="$(grep -c 'release create' "$FAKE_GH_DIR/calls.log" 2>/dev/null || true)"
  local bin_mtime_before
  bin_mtime_before="$(file_mtime "$WORK/gen/dist/denim_darwin_amd64")"

  local out status
  set +e
  out="$(run_release INPUT_VERSION=0.2.0 2>&1)"
  status=$?
  set -e
  [ "$status" -ne 0 ] || fail_case "$name" "re-run of an already-published version unexpectedly succeeded"
  printf '%s\n' "$out" | grep -q 'already has a published release' || fail_case "$name" "expected 'already has a published release' in output, got: $out"

  local post_master_sha
  post_master_sha="$(git --git-dir="$REMOTE_GIT" rev-parse master)"
  [ "$post_master_sha" = "$pre_master_sha" ] || fail_case "$name" "remote master sha changed on a refused re-run"

  local post_create_count
  post_create_count="$(grep -c 'release create' "$FAKE_GH_DIR/calls.log" 2>/dev/null || true)"
  [ "${post_create_count:-0}" -eq "${pre_create_count:-0}" ] || fail_case "$name" "unexpected new 'release create' call on a refused re-run"

  local bin_mtime_after
  bin_mtime_after="$(file_mtime "$WORK/gen/dist/denim_darwin_amd64")"
  [ "$bin_mtime_before" = "$bin_mtime_after" ] || fail_case "$name" "gen/dist was rebuilt on a re-run that should have been refused before build"

  pass_case "$name"
}

case_draft_cleanup() {
  local name="draft-cleanup"
  setup_fixture "$name"

  local out status
  set +e
  out="$(run_release INPUT_VERSION=0.2.0 FAKE_GH_CREATE_FAIL_AFTER_DRAFT=1 2>&1)"
  status=$?
  set -e
  [ "$status" -ne 0 ] || fail_case "$name" "first run (forced draft failure) unexpectedly succeeded"
  local state
  state="$(cat "$FAKE_GH_DIR/v0.2.0.state" 2>/dev/null || true)"
  [ "$state" = "draft" ] || fail_case "$name" "expected draft state after a forced mid-upload failure, got '$state'"

  set +e
  out="$(run_release INPUT_VERSION=0.2.0 2>&1)"
  status=$?
  set -e
  [ "$status" -eq 0 ] || fail_case "$name" "second run (draft cleanup) exited $status: $out"

  grep -qF 'release delete v0.2.0 --repo acme/denim-test --cleanup-tag --yes' "$FAKE_GH_DIR/calls.log" || fail_case "$name" "calls.log missing the expected release delete invocation"

  local delete_line second_create_line
  delete_line="$(grep -n 'release delete v0.2.0' "$FAKE_GH_DIR/calls.log" | head -1 | cut -d: -f1)"
  second_create_line="$(grep -n 'release create v0.2.0' "$FAKE_GH_DIR/calls.log" | tail -1 | cut -d: -f1)"
  [ -n "$delete_line" ] && [ -n "$second_create_line" ] && [ "$delete_line" -lt "$second_create_line" ] \
    || fail_case "$name" "expected release delete before the second release create in calls.log"

  state="$(cat "$FAKE_GH_DIR/v0.2.0.state")"
  [ "$state" = "published" ] || fail_case "$name" "expected final state published, got '$state'"

  local asset_count
  asset_count="$(find "$FAKE_GH_DIR/v0.2.0" -type f | wc -l | tr -d ' ')"
  [ "$asset_count" -eq 6 ] || fail_case "$name" "expected 6 assets in final published release, got $asset_count"

  pass_case "$name"
}

case_tag_without_release() {
  local name="tag-without-release"
  setup_fixture "$name"

  (
    cd "$WORK"
    git tag v0.2.0
    git push -q origin v0.2.0
  )

  local out status
  set +e
  out="$(run_release INPUT_VERSION=0.2.0 2>&1)"
  status=$?
  set -e
  [ "$status" -ne 0 ] || fail_case "$name" "run unexpectedly succeeded with an existing tag and no release"
  printf '%s\n' "$out" | grep -q 'exists without a release' || fail_case "$name" "expected 'exists without a release' in output, got: $out"

  local create_count
  create_count="$(grep -c 'release create' "$FAKE_GH_DIR/calls.log" 2>/dev/null || true)"
  [ "${create_count:-0}" -eq 0 ] || fail_case "$name" "unexpected release create call: ${create_count:-0}"
  [ ! -d "$WORK/gen/release" ] || fail_case "$name" "gen/release exists after a guard failure"

  pass_case "$name"
}

case_gh_error_fails_closed() {
  local name="gh-error-fails-closed"
  setup_fixture "$name"

  local out status
  set +e
  out="$(run_release INPUT_VERSION=0.2.0 FAKE_GH_VIEW_ERROR=1 2>&1)"
  status=$?
  set -e
  [ "$status" -ne 0 ] || fail_case "$name" "run unexpectedly succeeded with a forced gh view error"
  printf '%s\n' "$out" | grep -q 'HTTP 502' || fail_case "$name" "expected 'HTTP 502' in output, got: $out"

  local create_count
  create_count="$(grep -c 'release create' "$FAKE_GH_DIR/calls.log" 2>/dev/null || true)"
  [ "${create_count:-0}" -eq 0 ] || fail_case "$name" "unexpected release create call: ${create_count:-0}"

  pass_case "$name"
}

case_push_retry_rebase() {
  local name="push-retry-rebase"
  setup_fixture "$name"

  local second_clone="$CASE_DIR/second-clone"
  git clone -q "$REMOTE_GIT" "$second_clone"
  (
    cd "$second_clone"
    git config core.hooksPath "$EMPTY_HOOKS_DIR"
    git config user.name "denim-test-second-clone"
    git config user.email "second-clone@example.com"
    echo "unrelated fixture change" >> README.md
    git add -A
    git commit -q -m "fixture: unrelated commit pushed from a second clone"
    git push -q origin master
  )
  local unrelated_sha
  unrelated_sha="$(git --git-dir="$REMOTE_GIT" rev-parse master)"

  local out status
  set +e
  out="$(run_release INPUT_VERSION=0.2.0 2>&1)"
  status=$?
  set -e
  [ "$status" -eq 0 ] || fail_case "$name" "run exited $status when a single rebase retry should have resolved the rejected push: $out"

  local new_master_sha parent_sha
  new_master_sha="$(git --git-dir="$REMOTE_GIT" rev-parse master)"
  parent_sha="$(git --git-dir="$REMOTE_GIT" rev-parse "${new_master_sha}^")"
  [ "$parent_sha" = "$unrelated_sha" ] || fail_case "$name" "expected the formula commit's parent to be the unrelated commit ($unrelated_sha), got $parent_sha"

  pass_case "$name"
}

case_push_fails_twice() {
  local name="push-fails-twice"
  setup_fixture "$name"

  cat > "$REMOTE_GIT/hooks/pre-receive" <<'HOOK_EOF'
#!/usr/bin/env bash
while read -r oldrev newrev refname; do
  if [ "$refname" = "refs/heads/master" ]; then
    echo "rejected: master is protected in this fixture" >&2
    exit 1
  fi
done
exit 0
HOOK_EOF
  chmod 0755 "$REMOTE_GIT/hooks/pre-receive"

  local out status
  set +e
  out="$(run_release INPUT_VERSION=0.2.0 2>&1)"
  status=$?
  set -e
  [ "$status" -ne 0 ] || fail_case "$name" "run unexpectedly succeeded against a remote that rejects every push to master"

  printf '%s\n' "$out" | grep -qF 'v0.2.0' || fail_case "$name" "expected 'v0.2.0' in output, got: $out"

  local url_count sha_count
  url_count="$(printf '%s\n' "$out" | grep -cE '/releases/download/v0\.2\.0/' || true)"
  [ "${url_count:-0}" -eq 4 ] || fail_case "$name" "expected 4 release-download url lines in output, got ${url_count:-0}"

  sha_count="$(printf '%s\n' "$out" | grep -cE '[0-9a-f]{64}' || true)"
  [ "${sha_count:-0}" -eq 4 ] || fail_case "$name" "expected 4 sha256 lines in output, got ${sha_count:-0}"

  printf '%s\n' "$out" | grep -qF 'by hand' || fail_case "$name" "expected 'by hand' in output"
  printf '%s\n' "$out" | grep -qF 'immutable' || fail_case "$name" "expected 'immutable' in output"

  pass_case "$name"
}

case_wrong_branch() {
  local name="wrong-branch"
  setup_fixture "$name"

  (
    cd "$WORK"
    git checkout -q -b feature
  )

  local out status
  set +e
  out="$(run_release INPUT_VERSION=0.2.0 2>&1)"
  status=$?
  set -e
  [ "$status" -ne 0 ] || fail_case "$name" "run unexpectedly succeeded on a branch other than RELEASE_BRANCH"
  if [ -s "$FAKE_GH_DIR/calls.log" ]; then
    fail_case "$name" "calls.log has entries even though the branch check should fail before any gh call: $(cat "$FAKE_GH_DIR/calls.log")"
  fi

  pass_case "$name"
}

ALL_CASES=(
  happy-path
  next-version-auto
  invalid-input
  published-refuses
  draft-cleanup
  tag-without-release
  gh-error-fails-closed
  push-retry-rebase
  push-fails-twice
  wrong-branch
)

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
      published-refuses) case_published_refuses ;;
      draft-cleanup) case_draft_cleanup ;;
      tag-without-release) case_tag_without_release ;;
      gh-error-fails-closed) case_gh_error_fails_closed ;;
      push-retry-rebase) case_push_retry_rebase ;;
      push-fails-twice) case_push_fails_twice ;;
      wrong-branch) case_wrong_branch ;;
      *) echo "test-release: unknown case '$c'" >&2; exit 1 ;;
    esac
  done
  echo "test-release: ALL CASES PASSED"
}

main "$@"
