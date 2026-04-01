#!/usr/bin/env bash
set -euo pipefail

work_key="${1:-}"
mode="${2:-inplace}"

if [[ -z "$work_key" ]]; then
  echo "usage: $0 <work-key> [inplace|worktree]" >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "git is required" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

slug="$(
WORK_KEY="${work_key}" python3 <<'PY'
import os
import re

value = os.environ["WORK_KEY"].strip().lower()
value = re.sub(r"[^a-z0-9]+", "-", value)
print(value.strip("-") or "work")
PY
)"

branch_name="codex/${slug}"

repo_name="$(basename "${repo_root}")"

trunk_branch="$(
python3 <<'PY'
import subprocess

try:
    ref = subprocess.check_output(
        ["git", "symbolic-ref", "refs/remotes/origin/HEAD"],
        text=True,
    ).strip()
    print(ref.rsplit("/", 1)[-1])
except Exception:
    print("main")
PY
)"

cd "${repo_root}"

if [[ "${mode}" == "inplace" ]]; then
  current_branch="$(git branch --show-current)"
  if [[ "${current_branch}" != "${branch_name}" ]]; then
    if git show-ref --verify --quiet "refs/heads/${branch_name}"; then
      git checkout "${branch_name}" >/dev/null
    else
      git checkout "${trunk_branch}" >/dev/null
      git checkout -b "${branch_name}" >/dev/null
    fi
  fi

  BRANCH_NAME="${branch_name}" REPO_ROOT="${repo_root}" TRUNK_BRANCH="${trunk_branch}" python3 <<'PY'
import json
import os

print(json.dumps({
    "ok": True,
    "mode": "inplace",
    "branch": os.environ["BRANCH_NAME"],
    "path": os.environ["REPO_ROOT"],
    "trunk_branch": os.environ["TRUNK_BRANCH"],
}))
PY
  exit 0
fi

if [[ "${mode}" != "worktree" ]]; then
  echo "invalid mode: ${mode}" >&2
  exit 1
fi

worktree_path="$(cd "${repo_root}/.." && pwd)/${repo_name}-${slug}"

if [[ -d "${worktree_path}" ]]; then
  existing_branch="$(git -C "${worktree_path}" branch --show-current 2>/dev/null || true)"
  if [[ -n "${existing_branch}" && "${existing_branch}" != "${branch_name}" ]]; then
    echo "existing worktree at ${worktree_path} is on ${existing_branch}, expected ${branch_name}" >&2
    exit 1
  fi
else
  if git show-ref --verify --quiet "refs/heads/${branch_name}"; then
    git worktree add "${worktree_path}" "${branch_name}" >/dev/null
  else
    git worktree add -b "${branch_name}" "${worktree_path}" "${trunk_branch}" >/dev/null
  fi
fi

BRANCH_NAME="${branch_name}" WORKTREE_PATH="${worktree_path}" TRUNK_BRANCH="${trunk_branch}" python3 <<'PY'
import json
import os

print(json.dumps({
    "ok": True,
    "mode": "worktree",
    "branch": os.environ["BRANCH_NAME"],
    "path": os.environ["WORKTREE_PATH"],
    "trunk_branch": os.environ["TRUNK_BRANCH"],
}))
PY
