#!/usr/bin/env bash
set -euo pipefail

event_name="${1:?event name is required}"
base_ref="${2:-}"

if [[ "$event_name" == "pull_request" ]]; then
  if [[ -z "$base_ref" ]]; then
    echo "base ref is required for pull_request changed-file detection" >&2
    exit 64
  fi

  git fetch --no-tags --depth=1 origin "$base_ref"
  if git merge-base "origin/$base_ref" HEAD >/dev/null 2>&1; then
    git diff --name-only "origin/$base_ref"...HEAD
  else
    echo "merge base unavailable for origin/$base_ref...HEAD; falling back to tree diff against the pull request merge commit" >&2
    git diff --name-only "origin/$base_ref" HEAD
  fi
else
  git diff --name-only HEAD^ HEAD
fi
