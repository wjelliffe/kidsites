#!/usr/bin/env bash
set -euo pipefail

input_path="${1:-}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required" >&2
  exit 1
fi

if [[ -n "${input_path}" && ! -f "${input_path}" ]]; then
  echo "input file not found: ${input_path}" >&2
  exit 1
fi

INPUT_PATH="${input_path}" python3 <<'PY'
import json
import os
import re
import sys


def read_text(path: str) -> str:
    if not path:
        return sys.stdin.read()
    with open(path, "r", encoding="utf-8") as handle:
        return handle.read()


text = read_text(os.environ.get("INPUT_PATH", "")).strip()
lowered = text.lower()

issue_type = "user_story"
if re.search(r"\b(bug|defect|broken|regression|fix)\b", lowered):
    issue_type = "bug"
elif re.search(r"\b(epic|initiative|program)\b", lowered):
    issue_type = "epic"
elif re.search(r"\b(task|chore|cleanup|maintenance)\b", lowered):
    issue_type = "task"
elif re.search(r"\b(user story|as a |i want to |so that)\b", lowered):
    issue_type = "user_story"

payload = {
    "ok": True,
    "issue_type": issue_type,
    "defaulted": issue_type == "user_story" and not re.search(r"\b(epic|bug|defect|broken|regression|fix|task|chore|cleanup|maintenance|user story)\b", lowered),
}
print(json.dumps(payload, indent=2))
PY
