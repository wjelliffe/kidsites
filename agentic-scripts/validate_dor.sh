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


def present(value):
    if isinstance(value, list):
        return len([item for item in value if str(item).strip()]) > 0
    return bool(str(value).strip()) if value is not None else False


with open(os.environ["INPUT_PATH"], "r", encoding="utf-8") as handle:
    payload = json.load(handle)

issue_type = payload.get("issue_type", "user_story")
checks = []

checks.append({"name": "issue_type_identified", "pass": issue_type in {"epic", "user_story", "task", "bug"}})
if issue_type == "bug":
    checks.append({"name": "summary_clear", "pass": present(payload.get("problem")) or present(payload.get("summary"))})
    checks.append({"name": "expected_result_present", "pass": present(payload.get("expected_result")) or present(payload.get("goal")) or present(payload.get("objective"))})
    checks.append({"name": "actual_result_present", "pass": present(payload.get("actual_result")) or present(payload.get("problem"))})
    checks.append({"name": "acceptance_sufficient", "pass": present(payload.get("acceptance_criteria"))})
elif issue_type == "task":
    checks.append({"name": "summary_clear", "pass": present(payload.get("problem")) or present(payload.get("summary"))})
    checks.append({"name": "goal_present", "pass": present(payload.get("goal")) or present(payload.get("objective")) or present(payload.get("value"))})
    checks.append({"name": "scope_bounded", "pass": present(payload.get("scope"))})
    checks.append({"name": "acceptance_sufficient", "pass": present(payload.get("acceptance_criteria"))})
elif issue_type == "user_story":
    checks.append({"name": "user_story_present", "pass": present(payload.get("user_story")) or present(payload.get("problem")) or present(payload.get("summary"))})
    checks.append({"name": "summary_clear", "pass": present(payload.get("problem")) or present(payload.get("summary"))})
    checks.append({"name": "scope_bounded", "pass": present(payload.get("scope")) or present(payload.get("goal")) or present(payload.get("objective")) or present(payload.get("value"))})
    checks.append({"name": "acceptance_sufficient", "pass": present(payload.get("acceptance_criteria"))})
else:
    checks.append({"name": "epic_present", "pass": present(payload.get("problem")) or present(payload.get("summary")) or present(payload.get("title"))})
    checks.append({"name": "scope_present", "pass": present(payload.get("scope")) or present(payload.get("goal")) or present(payload.get("objective")) or present(payload.get("value"))})
    checks.append({"name": "breakdown_present", "pass": present(payload.get("acceptance_criteria"))})
    checks.append({"name": "success_criteria_present", "pass": present(payload.get("success_criteria")) or present(payload.get("acceptance_criteria"))})

if present(payload.get("dependencies")):
    checks.append({"name": "dependencies_captured", "pass": True})
if present(payload.get("constraints")):
    checks.append({"name": "constraints_captured", "pass": True})
if present(payload.get("test_expectations")) or present(payload.get("test_intent")):
    checks.append({"name": "test_expectations_captured", "pass": True})
if present(payload.get("architecture_notes")):
    checks.append({"name": "architecture_notes_captured", "pass": True})
if present(payload.get("design_notes")):
    checks.append({"name": "design_notes_captured", "pass": True})
if present(payload.get("reporting_notes")):
    checks.append({"name": "reporting_notes_captured", "pass": True})
if present(payload.get("documentation_notes")):
    checks.append({"name": "documentation_notes_captured", "pass": True})
if present(payload.get("risks")) or present(payload.get("edge_cases")):
    checks.append({"name": "risks_captured", "pass": True})

failed = [check["name"] for check in checks if not check["pass"]]

print(json.dumps({
    "ok": len(failed) == 0,
    "issue_type": issue_type,
    "failed_checks": failed,
    "checks": checks,
}, indent=2))
PY
