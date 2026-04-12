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
import re


def as_list(value):
    if isinstance(value, list):
        return [str(item).strip() for item in value if str(item).strip()]
    if isinstance(value, str) and value.strip():
        return [value.strip()]
    return []


def slugify(value):
    value = re.sub(r"[^a-z0-9]+", "-", str(value).lower())
    return value.strip("-") or "issue"


def as_story_list(payload):
    for key in ("stories", "user_stories", "child_issues", "breakdown"):
        value = payload.get(key)
        if isinstance(value, list) and value:
            return value
    return []


def combine_labels(*values):
    ordered = []
    for value in values:
        for item in as_list(value):
            if item not in ordered:
                ordered.append(item)
    return ordered


def render_issue(issue_type, payload):
    title = (payload.get("title") or payload.get("summary") or "Untitled issue").strip()
    problem = (payload.get("problem") or payload.get("objective") or title).strip()
    expected_result = (payload.get("expected_result") or payload.get("goal") or payload.get("objective") or "").strip()
    actual_result = (payload.get("actual_result") or payload.get("problem") or "").strip()
    goal = (payload.get("goal") or payload.get("objective") or payload.get("value") or "").strip()
    value = (payload.get("value") or "").strip()
    scope = (payload.get("scope") or "").strip()
    user_story = (payload.get("user_story") or "").strip()
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
    if issue_type == "bug":
        lines.append("## Summary")
        lines.append(problem)
        if expected_result:
            lines.append("")
            lines.append("## Expected Result")
            lines.append(expected_result)
        if actual_result:
            lines.append("")
            lines.append("## Actual Result")
            lines.append(actual_result)
        if acceptance:
            lines.append("")
            lines.append("## Acceptance Criteria")
            lines.extend(f"- [ ] {item}" for item in acceptance)

        implementation_notes = []
        for item in constraints:
            implementation_notes.append(item)
        for item in dependencies:
            implementation_notes.append(item)
        for item in architecture:
            implementation_notes.append(item)
        for item in design:
            implementation_notes.append(item)
        for item in reporting:
            implementation_notes.append(item)
        for item in documentation:
            implementation_notes.append(item)
        for item in risks:
            implementation_notes.append(item)
        if scope:
            implementation_notes.insert(0, f"Scope: {scope}")

        if implementation_notes:
            lines.append("")
            lines.append("## Implementation Notes")
            lines.extend(f"- {item}" for item in implementation_notes)

        if tests:
            lines.append("")
            lines.append("## Validation")
            lines.extend(f"- {item}" for item in tests)
    elif issue_type == "task":
        lines.append("## Summary")
        lines.append(problem)
        if goal:
            lines.append("")
            lines.append("## Goal")
            lines.append(goal)
        if scope:
            lines.append("")
            lines.append("## Scope")
            lines.append(scope)
        if acceptance:
            lines.append("")
            lines.append("## Acceptance Criteria")
            lines.extend(f"- [ ] {item}" for item in acceptance)

        implementation_notes = []
        for item in constraints:
            implementation_notes.append(item)
        for item in dependencies:
            implementation_notes.append(item)
        for item in architecture:
            implementation_notes.append(item)
        for item in design:
            implementation_notes.append(item)
        for item in reporting:
            implementation_notes.append(item)
        for item in documentation:
            implementation_notes.append(item)
        for item in risks:
            implementation_notes.append(item)
        if non_goals:
            implementation_notes.extend(f"Non-goal: {item}" for item in non_goals)

        if implementation_notes:
            lines.append("")
            lines.append("## Implementation Notes")
            lines.extend(f"- {item}" for item in implementation_notes)

        if tests:
            lines.append("")
            lines.append("## Validation")
            lines.extend(f"- {item}" for item in tests)
    elif issue_type == "user_story":
        lines.append("## User Story")
        lines.append(user_story or problem)
        lines.append("")
        lines.append("## Summary")
        lines.append(problem)
        if scope or goal:
            lines.append("")
            lines.append("## Scope")
            lines.append(scope or goal)
        if acceptance:
            lines.append("")
            lines.append("## Acceptance Criteria")
            lines.extend(f"- [ ] {item}" for item in acceptance)

        technical_notes = []
        for item in constraints:
            technical_notes.append(item)
        for item in dependencies:
            technical_notes.append(item)
        for item in architecture:
            technical_notes.append(item)
        for item in design:
            technical_notes.append(item)
        for item in reporting:
            technical_notes.append(item)
        for item in documentation:
            technical_notes.append(item)
        for item in risks:
            technical_notes.append(item)
        for item in non_goals:
            technical_notes.append(f"Non-goal: {item}")

        if technical_notes:
            lines.append("")
            lines.append("## Technical Notes")
            lines.extend(f"- {item}" for item in technical_notes)

        if tests:
            lines.append("")
            lines.append("## Validation")
            lines.extend(f"- {item}" for item in tests)
    else:
        lines.append("## Epic")
        lines.append(problem)
        if scope or goal or value:
            lines.append("")
            lines.append("## Scope")
            lines.append(scope or goal or value)

        breakdown_items = as_list(payload.get("acceptance_criteria"))
        story_titles = []
        for item in as_story_list(payload):
            if isinstance(item, dict):
                story_title = (item.get("title") or item.get("summary") or item.get("problem") or item.get("user_story") or "").strip()
            else:
                story_title = str(item).strip()
            if story_title:
                story_titles.append(story_title)
        if story_titles:
            breakdown_items = story_titles

        if breakdown_items:
            lines.append("")
            lines.append("## Breakdown")
            lines.extend(f"- {item}" for item in breakdown_items)

        success_criteria = as_list(payload.get("success_criteria")) or as_list(payload.get("acceptance_criteria"))
        if success_criteria:
            lines.append("")
            lines.append("## Success Criteria")
            lines.extend(f"- [ ] {item}" for item in success_criteria)

        technical_notes = []
        for item in architecture:
            technical_notes.append(item)
        for item in constraints:
            technical_notes.append(item)
        if technical_notes:
            lines.append("")
            lines.append("## Technical Notes")
            lines.extend(f"- {item}" for item in technical_notes)

        non_functional_scope = []
        for item in design:
            non_functional_scope.append(item)
        for item in reporting:
            non_functional_scope.append(item)
        for item in documentation:
            non_functional_scope.append(item)
        if non_functional_scope:
            lines.append("")
            lines.append("## Non-Functional Scope")
            lines.extend(f"- {item}" for item in non_functional_scope)

        dependencies_and_risks = []
        for item in dependencies:
            dependencies_and_risks.append(item)
        for item in risks:
            dependencies_and_risks.append(item)
        for item in non_goals:
            dependencies_and_risks.append(f"Non-goal: {item}")
        if dependencies_and_risks:
            lines.append("")
            lines.append("## Dependencies / Risks")
            lines.extend(f"- {item}" for item in dependencies_and_risks)

    return {
        "title": title,
        "body": "\n".join(lines).strip(),
    }


def normalize_story(index, story, default_labels):
    if isinstance(story, str):
        payload = {
            "title": story.strip() or f"Story {index}",
            "problem": story.strip(),
            "issue_type": "user_story",
            "labels": list(default_labels),
        }
    else:
        payload = dict(story)
        payload["labels"] = combine_labels(default_labels, payload.get("labels"))

    if not (payload.get("title") or payload.get("summary") or payload.get("problem") or payload.get("user_story")):
        payload["title"] = f"Story {index}"
    payload.setdefault("issue_type", "user_story")
    payload.setdefault("key", f"story-{index}")
    return payload


with open(os.environ["INPUT_PATH"], "r", encoding="utf-8") as handle:
    payload = json.load(handle)

issue_type = payload.get("issue_type", "user_story")
base_labels = as_list(payload.get("labels"))
rendered = render_issue(issue_type, payload)

issues = [
    {
        "key": payload.get("key") or ("epic" if issue_type == "epic" else slugify(rendered["title"])),
        "role": "parent" if issue_type == "epic" else "standalone",
        "title": rendered["title"],
        "body": rendered["body"],
        "labels": base_labels,
    }
]

if issue_type == "epic":
    parent_key = issues[0]["key"]
    for index, story in enumerate(as_story_list(payload), start=1):
        story_payload = normalize_story(index, story, base_labels)
        story_type = story_payload.get("issue_type", "user_story")
        rendered_story = render_issue(story_type, story_payload)
        issues.append({
            "key": story_payload.get("key") or f"story-{index}",
            "role": "sub_issue",
            "parent_key": parent_key,
            "title": rendered_story["title"],
            "body": rendered_story["body"],
            "labels": as_list(story_payload.get("labels")),
        })

bundle = {
    "ok": True,
    "issue_type": issue_type,
    "count": len(issues),
    "issues": issues,
}

print(json.dumps(bundle, indent=2))
PY
