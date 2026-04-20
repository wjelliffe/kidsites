#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"
input_path="${2:-}"

if [[ "${mode}" != "issue" && "${mode}" != "request" && "${mode}" != "minimal" ]]; then
  echo "usage: $0 <issue|request|minimal> [input-json-path]" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required" >&2
  exit 1
fi

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
tmp_dir="${repo_root}/.tmp"
mkdir -p "${tmp_dir}"

if [[ "${mode}" == "issue" ]]; then
  if [[ -z "${input_path}" || ! -f "${input_path}" ]]; then
    echo "issue mode requires an existing normalized issue json path" >&2
    exit 1
  fi
fi

raw_request=""
if [[ "${mode}" == "request" || "${mode}" == "minimal" ]]; then
  raw_request="$(cat)"
fi

INPUT_MODE="${mode}" INPUT_PATH="${input_path}" TMP_DIR="${tmp_dir}" RAW_REQUEST="${raw_request}" python3 <<'PY'
import json
import os
import re
from datetime import datetime, timezone


def slugify(value: str) -> str:
    value = value.lower()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    return value.strip("-") or "work"


mode = os.environ["INPUT_MODE"]
tmp_dir = os.environ["TMP_DIR"]

if mode == "issue":
    with open(os.environ["INPUT_PATH"], "r", encoding="utf-8") as handle:
        source = json.load(handle)
    normalized = source.get("normalized", {})
    issues = source.get("issues") or ([source.get("issue")] if source.get("issue") else [])
    issue_numbers = [item.get("number") for item in issues if isinstance(item, dict) and item.get("number") is not None]
    grouped_issue_numbers = normalized.get("issue_numbers") or issue_numbers
    grouped_issues = normalized.get("issues") or []
    is_issue_group = len(grouped_issue_numbers) > 1
    if is_issue_group and any(item.get("sub_issues") for item in grouped_issues if isinstance(item, dict)):
        raise SystemExit("issue groups cannot include parent issues with child issues")

    title = normalized.get("title") or source.get("issue", {}).get("title") or "Untitled issue"
    slug = normalized.get("slug") or slugify(title)
    parent_issue = normalized.get("parent_issue")
    parent_issues = normalized.get("parent_issues") or []
    sub_issues = normalized.get("sub_issues") or []
    closing_issue_number = source.get("issue", {}).get("number")
    closing_issue_numbers = None
    execution_role = "standalone_issue"
    epic_registry_path = None

    if is_issue_group:
        closing_issue_number = None
        closing_issue_numbers = grouped_issue_numbers
        execution_role = "issue_group"
    elif sub_issues:
        closing_issue_number = None
        execution_role = "epic"
        epic_registry_path = os.path.join(tmp_dir, f"sdlc-epic-{source.get('issue', {}).get('number')}-worktrees.json")
    elif isinstance(parent_issue, dict) and parent_issue.get("number"):
        execution_role = "child_issue"
        epic_registry_path = os.path.join(tmp_dir, f"sdlc-epic-{parent_issue.get('number')}-worktrees.json")

    context = {
        "schema_version": 1,
        "context_type": "issue",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "slug": slug,
        "title": title,
        "issue_number": source.get("issue", {}).get("number"),
        "issue_numbers": grouped_issue_numbers,
        "closing_issue_number": closing_issue_number,
        "closing_issue_numbers": closing_issue_numbers,
        "execution_role": execution_role,
        "parent_issue": parent_issue,
        "parent_issues": parent_issues,
        "sub_issues": sub_issues,
        "epic_registry_path": epic_registry_path,
        "summary": normalized.get("objective") or normalized.get("problem") or title,
        "problem": normalized.get("problem", ""),
        "scope": normalized.get("scope", ""),
        "dependencies": normalized.get("dependencies", []),
        "constraints": normalized.get("constraints", []),
        "acceptance_criteria": normalized.get("acceptance_criteria", []),
        "test_expectations": normalized.get("test_intent", []),
        "risks": normalized.get("risks", []),
        "source_issue_path": os.environ["INPUT_PATH"],
    }
elif mode == "request":
    raw_request = os.environ.get("RAW_REQUEST", "").strip()
    if not raw_request:
        raise SystemExit("request mode requires stdin input")
    slug = slugify(raw_request[:80])
    context = {
        "schema_version": 1,
        "context_type": "request",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "slug": slug,
        "title": raw_request.splitlines()[0][:120],
        "summary": raw_request,
        "execution_role": "request",
        "problem": "",
        "scope": "",
        "dependencies": [],
        "constraints": [],
        "acceptance_criteria": [],
        "test_expectations": [],
        "risks": [],
        "parent_issue": None,
        "sub_issues": [],
        "epic_registry_path": None,
    }
else:
    raw_request = os.environ.get("RAW_REQUEST", "").strip()
    if not raw_request:
        raise SystemExit("minimal mode requires stdin input")
    title = raw_request.splitlines()[0][:120]
    context = {
        "schema_version": 1,
        "context_type": "minimal",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "slug": slugify(title or raw_request[:80]),
        "title": title,
        "summary": raw_request,
        "closing_issue_number": None,
        "execution_role": "minimal",
        "parent_issue": None,
        "sub_issues": [],
        "epic_registry_path": None,
    }

output_path = os.path.join(tmp_dir, f"sdlc-context-{context['slug']}.json")
with open(output_path, "w", encoding="utf-8") as handle:
    json.dump(context, handle, indent=2, sort_keys=True)
    handle.write("\n")

print(json.dumps({"ok": True, "path": output_path, "slug": context["slug"], "context_type": context["context_type"]}))
PY
