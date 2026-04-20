#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 1 ]]; then
  echo "usage: $0 <issue-number> [<issue-number> ...]" >&2
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
issue_numbers=("$@")

if [[ "${#issue_numbers[@]}" -eq 1 ]]; then
  output_path="${tmp_dir}/issue-${issue_numbers[0]}.json"
else
  joined_issue_numbers="$(printf '%s-' "${issue_numbers[@]}")"
  joined_issue_numbers="${joined_issue_numbers%-}"
  output_path="${tmp_dir}/issue-bundle-${joined_issue_numbers}.json"
fi

mkdir -p "${tmp_dir}"

repo_json="$(gh repo view --json nameWithOwner)"
raw_json="$(
  python3 - "${issue_numbers[@]}" <<'PY'
import json
import subprocess
import sys

issues = []
for issue_number in sys.argv[1:]:
    proc = subprocess.run(
        ["gh", "issue", "view", issue_number, "--json", "number,title,body,url,state,labels,assignees,author"],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise SystemExit(proc.stderr.strip() or f"gh issue view failed for {issue_number}")
    issues.append(json.loads(proc.stdout))

print(json.dumps(issues))
PY
)"

RAW_JSON="${raw_json}" REPO_JSON="${repo_json}" OUTPUT_PATH="${output_path}" python3 <<'PY'
import json
import os
import re
import subprocess
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


def gh_api(path: str):
    proc = subprocess.run(
        ["gh", "api", path],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        if "404" in (proc.stderr or ""):
            return None
        raise SystemExit(proc.stderr.strip() or f"gh api failed for {path}")
    return json.loads(proc.stdout)


def merge_unique(items):
    merged = []
    seen = set()
    for value in items:
        if value is None:
            continue
        if isinstance(value, list):
            for entry in value:
                key = json.dumps(entry, sort_keys=True) if isinstance(entry, (dict, list)) else str(entry)
                if key in seen:
                    continue
                seen.add(key)
                merged.append(entry)
            continue
        key = json.dumps(value, sort_keys=True) if isinstance(value, dict) else str(value).strip()
        if not key or key in seen:
            continue
        seen.add(key)
        merged.append(value)
    return merged


raw_items = json.loads(os.environ["RAW_JSON"])
repo = json.loads(os.environ["REPO_JSON"])
name_with_owner = repo.get("nameWithOwner", "")
owner, repo_name = name_with_owner.split("/", 1)

normalized_items = []
issues = []
for raw in raw_items:
    body = raw.get("body") or ""
    sections = parse_sections(body)
    acceptance_source = "\n".join(
        sections.get(name, "")
        for name in ("acceptance-criteria", "acceptance", "definition-of-done", "dod")
        if sections.get(name)
    ).strip()
    acceptance = extract_checklist(acceptance_source) or extract_bullets(acceptance_source) or extract_checklist(body)
    parent_issue = gh_api(f"repos/{owner}/{repo_name}/issues/{raw['number']}/parent")
    sub_issues = gh_api(f"repos/{owner}/{repo_name}/issues/{raw['number']}/sub_issues") or []

    normalized_items.append({
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
        "parent_issue": {
            "number": parent_issue.get("number"),
            "title": parent_issue.get("title"),
            "url": parent_issue.get("html_url"),
        } if isinstance(parent_issue, dict) else None,
        "sub_issues": [
            {
                "number": item.get("number"),
                "title": item.get("title"),
                "url": item.get("html_url"),
            }
            for item in sub_issues
        ],
        "sections": sections,
    })
    issues.append({
        "number": raw["number"],
        "title": raw.get("title", ""),
        "body": body,
        "url": raw.get("url", ""),
        "state": raw.get("state", ""),
        "author": (raw.get("author") or {}).get("login"),
        "labels": [label["name"] for label in raw.get("labels", [])],
        "assignees": [assignee["login"] for assignee in raw.get("assignees", [])],
    })

primary_issue = issues[0]
primary_normalized = normalized_items[0]

if len(normalized_items) == 1:
    normalized = primary_normalized
else:
    issue_numbers = [item["issue_number"] for item in normalized_items]
    normalized = {
        "issue_numbers": issue_numbers,
        "issue_number": primary_normalized["issue_number"],
        "slug": "issues-" + "-".join(str(number) for number in issue_numbers),
        "title": " + ".join(item["title"] for item in normalized_items if item.get("title")),
        "problem": "\n\n".join(item["problem"] for item in normalized_items if item.get("problem")),
        "objective": "\n".join(f"- {item['objective']}" for item in normalized_items if item.get("objective")),
        "value": "\n\n".join(item["value"] for item in normalized_items if item.get("value")),
        "scope": "\n\n".join(item["scope"] for item in normalized_items if item.get("scope")),
        "non_goals": merge_unique(item.get("non_goals", []) for item in normalized_items),
        "dependencies": merge_unique(item.get("dependencies", []) for item in normalized_items),
        "constraints": merge_unique(item.get("constraints", []) for item in normalized_items),
        "acceptance_criteria": merge_unique(item.get("acceptance_criteria", []) for item in normalized_items),
        "risks": merge_unique(item.get("risks", []) for item in normalized_items),
        "test_intent": merge_unique(item.get("test_intent", []) for item in normalized_items),
        "implementation_hints": merge_unique(item.get("implementation_hints", []) for item in normalized_items),
        "parent_issue": None,
        "parent_issues": merge_unique(item.get("parent_issue") for item in normalized_items),
        "sub_issues": merge_unique(item.get("sub_issues", []) for item in normalized_items),
        "sections": {
            str(item["issue_number"]): item.get("sections", {})
            for item in normalized_items
        },
        "issues": normalized_items,
    }

payload = {
    "schema_version": 1,
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "source": "gh issue view",
    "issue": primary_issue,
    "issues": issues,
    "normalized": normalized,
}

if len(issues) > 1:
    payload["issue_count"] = len(issues)
    payload["issue_numbers"] = [item["number"] for item in issues]

with open(os.environ["OUTPUT_PATH"], "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2, sort_keys=True)
    handle.write("\n")

print(json.dumps({
    "ok": True,
    "path": os.environ["OUTPUT_PATH"],
    "issue_number": issues[0]["number"] if len(issues) == 1 else None,
    "issue_numbers": [item["number"] for item in issues],
}))
PY
