#!/usr/bin/env bash
set -euo pipefail

issue_number="${1:-}"

if [[ -z "$issue_number" ]]; then
  echo "usage: $0 <issue-number>" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
tmp_dir="${repo_root}/.tmp"
output_path="${tmp_dir}/issue-${issue_number}.json"

mkdir -p "${tmp_dir}"

raw_json="$(gh issue view "${issue_number}" --json number,title,body,url,state,labels,assignees,author)"

RAW_JSON="${raw_json}" ISSUE_NUMBER="${issue_number}" OUTPUT_PATH="${output_path}" python3 <<'PY'
import json
import os
import re
from datetime import datetime, timezone


def slugify(value: str) -> str:
    value = value.lower()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    return value.strip("-")


def parse_sections(body: str) -> dict[str, str]:
    sections: dict[str, list[str]] = {}
    current = "summary"
    sections[current] = []
    for line in body.splitlines():
        match = re.match(r"^\s{0,3}#{1,6}\s+(.+?)\s*$", line)
        if match:
            current = slugify(match.group(1)) or current
            sections.setdefault(current, [])
            continue
        sections.setdefault(current, []).append(line)
    return {key: "\n".join(value).strip() for key, value in sections.items() if "\n".join(value).strip()}


def extract_checklist(body: str) -> list[str]:
    items: list[str] = []
    for line in body.splitlines():
        match = re.match(r"^\s*[-*]\s+\[.\]\s+(.+?)\s*$", line)
        if match:
            items.append(match.group(1).strip())
    return items


def extract_bullets(text: str) -> list[str]:
    items: list[str] = []
    for line in text.splitlines():
        match = re.match(r"^\s*[-*]\s+(.+?)\s*$", line)
        if match:
            items.append(match.group(1).strip())
    return items


raw = json.loads(os.environ["RAW_JSON"])
body = raw.get("body") or ""
sections = parse_sections(body)
acceptance_source = "\n".join(
    sections.get(name, "")
    for name in ("acceptance-criteria", "acceptance", "definition-of-done", "dod")
    if sections.get(name)
).strip()
acceptance = extract_checklist(acceptance_source) or extract_bullets(acceptance_source) or extract_checklist(body)

normalized = {
    "issue_number": raw["number"],
    "slug": slugify(raw.get("title") or f"issue-{raw['number']}"),
    "title": raw.get("title", ""),
    "problem": sections.get("problem", ""),
    "objective": sections.get("objective", raw.get("title", "")),
    "value": sections.get("value", ""),
    "scope": sections.get("scope", ""),
    "non_goals": extract_bullets(sections.get("non-goals", "")),
    "dependencies": extract_bullets(sections.get("dependencies", "")),
    "constraints": extract_bullets(sections.get("constraints", "")),
    "acceptance_criteria": acceptance,
    "risks": extract_bullets(sections.get("risks", "")) or extract_bullets(sections.get("edge-cases-risks", "")),
    "test_intent": extract_bullets(sections.get("test-intent", "")) or extract_bullets(sections.get("test-plan", "")),
    "implementation_hints": extract_bullets(sections.get("implementation-hints", "")),
    "sections": sections,
}

payload = {
    "schema_version": 1,
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "source": "gh issue view",
    "issue": {
        "number": raw["number"],
        "title": raw.get("title", ""),
        "body": body,
        "url": raw.get("url", ""),
        "state": raw.get("state", ""),
        "author": (raw.get("author") or {}).get("login"),
        "labels": [label["name"] for label in raw.get("labels", [])],
        "assignees": [assignee["login"] for assignee in raw.get("assignees", [])],
    },
    "normalized": normalized,
}

with open(os.environ["OUTPUT_PATH"], "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2, sort_keys=True)
    handle.write("\n")

print(json.dumps({"ok": True, "path": os.environ["OUTPUT_PATH"], "issue_number": raw["number"]}))
PY
