#!/usr/bin/env bash
set -euo pipefail

script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ci_changed_files.sh"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

setup_git_identity() {
  git config user.email "ci@example.test"
  git config user.name "CI Test"
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL: %s\nexpected:\n%s\nactual:\n%s\n' "$message" "$expected" "$actual" >&2
    exit 1
  fi
}

test_push_diff() {
  local repo="$tmpdir/push"
  mkdir "$repo"
  cd "$repo"
  git init -q
  setup_git_identity

  printf 'first\n' > README.md
  git add README.md
  git commit -qm "initial"

  mkdir -p app/javascript
  printf 'console.log("changed")\n' > app/javascript/application.js
  git add app/javascript/application.js
  git commit -qm "change root js"

  local output
  output="$(bash "$script_path" push "")"

  assert_eq "app/javascript/application.js" "$output" "push events use HEAD^ HEAD"
}

test_pull_request_triple_dot_diff() {
  local remote="$tmpdir/pr-remote.git"
  local repo="$tmpdir/pr"
  git init -q --bare "$remote"
  git init -q "$repo"
  cd "$repo"
  setup_git_identity
  git remote add origin "$remote"

  printf 'base\n' > README.md
  git add README.md
  git commit -qm "base"
  git branch -M main
  git push -q origin main

  git checkout -qb feature
  mkdir -p config
  printf 'export default {}\n' > config/vite.config.js
  git add config/vite.config.js
  git commit -qm "feature change"

  local output
  output="$(bash "$script_path" pull_request main)"

  assert_eq "config/vite.config.js" "$output" "pull_request events use triple-dot diff when merge-base exists"
}

test_pull_request_tree_diff_fallback() {
  local remote="$tmpdir/fallback-remote.git"
  local repo="$tmpdir/fallback"
  git init -q --bare "$remote"
  git init -q "$repo"
  cd "$repo"
  setup_git_identity
  git remote add origin "$remote"

  printf 'main\n' > package.json
  git add package.json
  git commit -qm "main root"
  git branch -M main
  git push -q origin main

  git checkout -q --orphan feature
  git rm -qrf .
  mkdir -p docusaurus
  printf '{"lockfileVersion": 3}\n' > docusaurus/package-lock.json
  git add docusaurus/package-lock.json
  git commit -qm "unrelated feature root"

  local stdout_file="$tmpdir/fallback.stdout"
  local stderr_file="$tmpdir/fallback.stderr"
  bash "$script_path" pull_request main >"$stdout_file" 2>"$stderr_file"

  grep -qx 'docusaurus/package-lock.json' "$stdout_file"
  grep -qx 'package.json' "$stdout_file"
  grep -q 'merge base unavailable for origin/main...HEAD; falling back to tree diff against the pull request merge commit' "$stderr_file"
}

test_push_diff
test_pull_request_triple_dot_diff
test_pull_request_tree_diff_fallback

printf 'ci_changed_files tests passed\n'
