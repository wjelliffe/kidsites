#!/usr/bin/env bash
set -euo pipefail

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
  echo "summarize_diff.sh must be executed inside a git repository" >&2
  exit 1
fi

branch_name="$(git branch --show-current)"
status_short="$(git status --short)"
diff_stat="$(git diff --stat)"
changed_files="$(git diff --name-only)"

BRANCH_NAME="${branch_name}" REPO_ROOT="${repo_root}" STATUS_SHORT="${status_short}" DIFF_STAT="${diff_stat}" CHANGED_FILES="${changed_files}" python3 <<'PY'
import json
import os

repo_root = os.environ["REPO_ROOT"]
changed = [line for line in os.environ.get("CHANGED_FILES", "").splitlines() if line.strip()]
payload = {
    "ok": True,
    "branch": os.environ.get("BRANCH_NAME", ""),
    "repo_root": repo_root,
    "status_short": [line for line in os.environ.get("STATUS_SHORT", "").splitlines() if line.strip()],
    "diff_stat": [line for line in os.environ.get("DIFF_STAT", "").splitlines() if line.strip()],
    "changed_files": changed,
    "absolute_changed_files": [os.path.join(repo_root, path) for path in changed],
    "clean": not changed and not os.environ.get("STATUS_SHORT", "").strip(),
}
print(json.dumps(payload, indent=2))
PY
