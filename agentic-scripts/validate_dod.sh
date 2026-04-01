#!/usr/bin/env bash
set -euo pipefail

context_path="${1:-}"
checks_path="${2:-}"
tests_path="${3:-}"

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
  echo "validate_dod.sh must be executed inside a git repository" >&2
  exit 1
fi

status_short="$(git status --short)"
changed_files="$(git diff --name-only)"

CONTEXT_PATH="${context_path}" CHECKS_PATH="${checks_path}" TESTS_PATH="${tests_path}" STATUS_SHORT="${status_short}" CHANGED_FILES="${changed_files}" python3 <<'PY'
import json
import os

status_lines = [line for line in os.environ.get("STATUS_SHORT", "").splitlines() if line.strip()]
changed_files = [line for line in os.environ.get("CHANGED_FILES", "").splitlines() if line.strip()]
context_path = os.environ.get("CONTEXT_PATH", "")
checks_path = os.environ.get("CHECKS_PATH", "")
tests_path = os.environ.get("TESTS_PATH", "")

checks = [
    {
        "name": "changes_present",
        "pass": bool(changed_files or status_lines),
        "detail": "Repository has changes to review." if (changed_files or status_lines) else "No tracked changes detected.",
    },
    {
        "name": "merge_conflicts_absent",
        "pass": not any(line.startswith("UU ") or line.startswith("AA ") for line in status_lines),
        "detail": "No merge conflicts detected." if not any(line.startswith("UU ") or line.startswith("AA ") for line in status_lines) else "Resolve merge conflicts before claiming DOD.",
    },
]

if context_path:
    checks.insert(1, {
        "name": "context_present",
        "pass": os.path.exists(context_path),
        "detail": context_path if os.path.exists(context_path) else f"Missing {context_path}",
    })

if checks_path:
    if os.path.exists(checks_path):
        with open(checks_path, "r", encoding="utf-8") as handle:
            payload = json.load(handle)
        checks.append({
            "name": "checks_passed",
            "pass": bool(payload.get("ok")),
            "detail": checks_path,
        })
    else:
        checks.append({
            "name": "checks_passed",
            "pass": False,
            "detail": f"Missing {checks_path}",
        })

if tests_path:
    if os.path.exists(tests_path):
        with open(tests_path, "r", encoding="utf-8") as handle:
            payload = json.load(handle)
        checks.append({
            "name": "tests_passed",
            "pass": bool(payload.get("ok")),
            "detail": tests_path,
        })
    else:
        checks.append({
            "name": "tests_passed",
            "pass": False,
            "detail": f"Missing {tests_path}",
        })

manual_items = [
    "tests were written first when practical",
    "review pass completed",
    "acceptance criteria satisfied",
    "no obvious regressions",
    "docs updated if needed",
    "risks noted",
    "ready for merge or pr",
]

failed = [item["name"] for item in checks if not item["pass"]]
payload = {
    "ok": len(failed) == 0,
    "failed_checks": failed,
    "checks": checks,
    "manual_review_required": manual_items,
}
print(json.dumps(payload, indent=2))
PY
