#!/usr/bin/env bash
set -euo pipefail

input_path="${1:-}"

if [[ -z "${input_path}" ]]; then
  echo "usage: $0 <normalized-issue-json>" >&2
  exit 1
fi

if [[ ! -f "${input_path}" ]]; then
  echo "input file not found: ${input_path}" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required" >&2
  exit 1
fi

INPUT_PATH="${input_path}" python3 <<'PY'
import json
import os


def as_list(value):
    if isinstance(value, list):
        return [str(item).strip() for item in value if str(item).strip()]
    if isinstance(value, str) and value.strip():
        return [value.strip()]
    return []


with open(os.environ["INPUT_PATH"], "r", encoding="utf-8") as handle:
    payload = json.load(handle)

issue_type = payload.get("issue_type", "user_story")
title = (payload.get("title") or payload.get("summary") or "Untitled issue").strip()
problem = (payload.get("problem") or payload.get("objective") or title).strip()
value = (payload.get("value") or "").strip()
scope = (payload.get("scope") or "").strip()
non_goals = as_list(payload.get("non_goals"))
dependencies = as_list(payload.get("dependencies"))
constraints = as_list(payload.get("constraints"))
acceptance = as_list(payload.get("acceptance_criteria"))
tests = as_list(payload.get("test_expectations") or payload.get("test_intent"))
architecture = as_list(payload.get("architecture_notes"))
design = as_list(payload.get("design_notes"))
reporting = as_list(payload.get("reporting_notes"))
documentation = as_list(payload.get("documentation_notes"))
risks = as_list(payload.get("risks") or payload.get("edge_cases"))

lines = []
lines.append("## Summary")
lines.append(problem)
if value:
    lines.append("")
    lines.append("## Value")
    lines.append(value)
if scope:
    lines.append("")
    lines.append("## Scope")
    lines.append(scope)
if non_goals:
    lines.append("")
    lines.append("## Non-Goals")
    lines.extend(f"- {item}" for item in non_goals)
if dependencies:
    lines.append("")
    lines.append("## Dependencies")
    lines.extend(f"- {item}" for item in dependencies)
if constraints:
    lines.append("")
    lines.append("## Constraints")
    lines.extend(f"- {item}" for item in constraints)
if acceptance:
    lines.append("")
    lines.append("## Acceptance Criteria")
    lines.extend(f"- [ ] {item}" for item in acceptance)
if tests:
    lines.append("")
    lines.append("## Test Expectations")
    lines.extend(f"- {item}" for item in tests)
if architecture:
    lines.append("")
    lines.append("## Architecture Notes")
    lines.extend(f"- {item}" for item in architecture)
if design:
    lines.append("")
    lines.append("## Design Notes")
    lines.extend(f"- {item}" for item in design)
if reporting:
    lines.append("")
    lines.append("## Reporting Notes")
    lines.extend(f"- {item}" for item in reporting)
if documentation:
    lines.append("")
    lines.append("## Documentation Notes")
    lines.extend(f"- {item}" for item in documentation)
if risks:
    lines.append("")
    lines.append("## Risks / Edge Cases")
    lines.extend(f"- {item}" for item in risks)

bundle = {
    "ok": True,
    "issue_type": issue_type,
    "count": 1,
    "issues": [
        {
            "title": title,
            "body": "\n".join(lines).strip(),
            "labels": as_list(payload.get("labels")),
        }
    ],
}

print(json.dumps(bundle, indent=2))
PY
