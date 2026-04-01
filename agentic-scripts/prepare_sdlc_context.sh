#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"
input_path="${2:-}"

if [[ "${mode}" != "issue" && "${mode}" != "request" ]]; then
  echo "usage: $0 <issue|request> [input-json-path]" >&2
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

INPUT_MODE="${mode}" INPUT_PATH="${input_path}" TMP_DIR="${tmp_dir}" python3 <<'PY'
import json
import os
import re
import sys
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
    title = normalized.get("title") or source.get("issue", {}).get("title") or "Untitled issue"
    slug = normalized.get("slug") or slugify(title)
    context = {
        "schema_version": 1,
        "context_type": "issue",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "slug": slug,
        "title": title,
        "issue_number": source.get("issue", {}).get("number"),
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
else:
    raw_request = sys.stdin.read().strip()
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
        "problem": "",
        "scope": "",
        "dependencies": [],
        "constraints": [],
        "acceptance_criteria": [],
        "test_expectations": [],
        "risks": [],
    }

output_path = os.path.join(tmp_dir, f"sdlc-context-{context['slug']}.json")
with open(output_path, "w", encoding="utf-8") as handle:
    json.dump(context, handle, indent=2, sort_keys=True)
    handle.write("\n")

print(json.dumps({"ok": True, "path": output_path, "slug": context["slug"], "context_type": context["context_type"]}))
PY
