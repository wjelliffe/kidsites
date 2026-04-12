#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"
context_path="${2:-}"

if [[ "${mode}" != "merge" && "${mode}" != "pr" ]]; then
  echo "usage: $0 <merge|pr> <context-json>" >&2
  echo "context-json may be full SDLC context or minimal FAST-success finalize context" >&2
  exit 1
fi

if [[ -z "${context_path}" || ! -f "${context_path}" ]]; then
  echo "context file not found: ${context_path}" >&2
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

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${repo_root}" ]]; then
  echo "finalize_work.sh must be executed inside a git repository" >&2
  exit 1
fi

main_worktree="$(
python3 <<'PY'
import subprocess

try:
    output = subprocess.check_output(["git", "worktree", "list", "--porcelain"], text=True)
except Exception:
    print("")
    raise SystemExit

for line in output.splitlines():
    if line.startswith("worktree "):
        print(line.split(" ", 1)[1].strip())
        break
PY
)"

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

current_branch="$(git branch --show-current)"

read_context="$(
CONTEXT_PATH="${context_path}" python3 <<'PY'
import json
import os

with open(os.environ["CONTEXT_PATH"], "r", encoding="utf-8") as handle:
    payload = json.load(handle)

title = payload.get("title") or payload.get("summary") or payload.get("slug") or "update"
issue_number = payload.get("issue_number")
summary = payload.get("summary") or title
print(json.dumps({
    "title": title,
    "issue_number": issue_number,
    "summary": summary,
}))
PY
)"

commit_subject="$(READ_CONTEXT="${read_context}" python3 <<'PY'
import json
import os
import re

payload = json.loads(os.environ["READ_CONTEXT"])
title = payload["title"].strip()
title = re.sub(r"\s+", " ", title)
print(f"feat: {title[:72]}")
PY
)"

issue_number="$(READ_CONTEXT="${read_context}" python3 <<'PY'
import json
import os
payload = json.loads(os.environ["READ_CONTEXT"])
print(payload.get("issue_number") or "")
PY
)"

git add -A
if [[ -n "${issue_number}" ]]; then
  git commit -m "${commit_subject}" -m "Fixes #${issue_number}" >/dev/null
else
  git commit -m "${commit_subject}" >/dev/null
fi

commit_sha="$(git rev-parse HEAD)"

if [[ "${mode}" == "merge" ]]; then
  worktree_removed="false"
  if [[ -n "${main_worktree}" && "${main_worktree}" != "${repo_root}" ]]; then
    git -C "${main_worktree}" checkout "${trunk_branch}" >/dev/null
    git -C "${main_worktree}" merge --ff-only "${current_branch}" >/dev/null || git -C "${main_worktree}" merge "${current_branch}" >/dev/null
    git -C "${main_worktree}" branch -d "${current_branch}" >/dev/null || true
    git -C "${main_worktree}" worktree remove "${repo_root}" >/dev/null || true
    worktree_removed="true"
  else
    git checkout "${trunk_branch}" >/dev/null
    git merge --ff-only "${current_branch}" >/dev/null || git merge "${current_branch}" >/dev/null
    git branch -d "${current_branch}" >/dev/null || true
  fi

  COMMIT_SHA="${commit_sha}" TRUNK_BRANCH="${trunk_branch}" MERGED_BRANCH="${current_branch}" WORKTREE_REMOVED="${worktree_removed}" python3 <<'PY'
import json
import os
print(json.dumps({
    "ok": True,
    "mode": "merge",
    "commit": os.environ["COMMIT_SHA"],
    "trunk_branch": os.environ["TRUNK_BRANCH"],
    "merged_branch": os.environ["MERGED_BRANCH"],
    "worktree_removed": os.environ["WORKTREE_REMOVED"] == "true",
}))
PY
  exit 0
fi

git push -u origin "${current_branch}" >/dev/null

pr_url="$(
READ_CONTEXT="${read_context}" CURRENT_BRANCH="${current_branch}" TRUNK_BRANCH="${trunk_branch}" python3 <<'PY'
import json
import os
import subprocess

payload = json.loads(os.environ["READ_CONTEXT"])
title = payload["title"].strip()
body = payload["summary"].strip()
issue_number = payload.get("issue_number")
cmd = [
    "gh", "pr", "create",
    "--title", title,
    "--body", body,
    "--base", os.environ["TRUNK_BRANCH"],
    "--head", os.environ["CURRENT_BRANCH"],
]
if issue_number:
    body = f"{body}\n\nResolves #{issue_number}"
    cmd = [
        "gh", "pr", "create",
        "--title", title,
        "--body", body,
        "--base", os.environ["TRUNK_BRANCH"],
        "--head", os.environ["CURRENT_BRANCH"],
    ]
proc = subprocess.run(cmd, capture_output=True, text=True)
if proc.returncode == 0:
    print(proc.stdout.strip())
else:
    print("")
PY
)"

COMMIT_SHA="${commit_sha}" CURRENT_BRANCH="${current_branch}" TRUNK_BRANCH="${trunk_branch}" PR_URL="${pr_url}" python3 <<'PY'
import json
import os
print(json.dumps({
    "ok": True,
    "mode": "pr",
    "commit": os.environ["COMMIT_SHA"],
    "branch": os.environ["CURRENT_BRANCH"],
    "trunk_branch": os.environ["TRUNK_BRANCH"],
    "pr_url": os.environ["PR_URL"],
}))
PY
