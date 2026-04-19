#!/usr/bin/env bash
set -euo pipefail

work_key="${1:-}"
mode="${2:-inplace}"
context_path="${3:-}"

if [[ -z "$work_key" ]]; then
  echo "usage: $0 <work-key> [inplace|worktree] [context-json]" >&2
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

if [[ -n "${context_path}" && ! -f "${context_path}" ]]; then
  echo "context file not found: ${context_path}" >&2
  exit 1
fi

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

register_child_worktree() {
  local context_path="$1"
  local branch_name="$2"
  local worktree_path="$3"

  [[ -n "${context_path}" ]] || return 0

  CONTEXT_PATH="${context_path}" BRANCH_NAME="${branch_name}" WORKTREE_PATH="${worktree_path}" python3 <<'PY'
import json
import os
from datetime import datetime, timezone

with open(os.environ["CONTEXT_PATH"], "r", encoding="utf-8") as handle:
    context = json.load(handle)

registry_path = context.get("epic_registry_path")
if context.get("execution_role") != "child_issue" or not registry_path:
    raise SystemExit(0)

os.makedirs(os.path.dirname(registry_path), exist_ok=True)
if os.path.exists(registry_path):
    with open(registry_path, "r", encoding="utf-8") as handle:
        registry = json.load(handle)
else:
    registry = {"schema_version": 1, "entries": []}

entry = {
    "issue_number": context.get("issue_number"),
    "closing_issue_number": context.get("closing_issue_number"),
    "title": context.get("title"),
    "branch": os.environ["BRANCH_NAME"],
    "path": os.environ["WORKTREE_PATH"],
    "status": "active",
    "registered_at": datetime.now(timezone.utc).isoformat(),
}

entries = [item for item in registry.get("entries", []) if item.get("path") != entry["path"] and item.get("branch") != entry["branch"]]
entries.append(entry)
registry["entries"] = entries

with open(registry_path, "w", encoding="utf-8") as handle:
    json.dump(registry, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
}

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

register_child_worktree "${context_path}" "${branch_name}" "${worktree_path}"
