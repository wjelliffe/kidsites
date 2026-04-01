#!/usr/bin/env bash
set -euo pipefail

bundle_path="${1:-}"

if [[ -z "${bundle_path}" ]]; then
  echo "usage: $0 <issue-bundle-json>" >&2
  exit 1
fi

if [[ ! -f "${bundle_path}" ]]; then
  echo "bundle file not found: ${bundle_path}" >&2
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

BUNDLE_PATH="${bundle_path}" python3 <<'PY'
import json
import os
import subprocess
import sys
import tempfile

with open(os.environ["BUNDLE_PATH"], "r", encoding="utf-8") as handle:
    payload = json.load(handle)

results = []
for issue in payload.get("issues", []):
    title = issue["title"]
    body = issue["body"]
    labels = issue.get("labels") or []
    with tempfile.NamedTemporaryFile("w", delete=False, encoding="utf-8") as tmp:
        tmp.write(body)
        tmp_path = tmp.name
    cmd = ["gh", "issue", "create", "--title", title, "--body-file", tmp_path]
    for label in labels:
        cmd.extend(["--label", label])
    proc = subprocess.run(cmd, capture_output=True, text=True)
    os.unlink(tmp_path)
    if proc.returncode != 0:
        print(json.dumps({
            "ok": False,
            "failed_title": title,
            "stderr": proc.stderr.strip(),
        }, indent=2))
        sys.exit(proc.returncode)
    results.append({
        "title": title,
        "url": proc.stdout.strip(),
        "labels": labels,
    })

print(json.dumps({
    "ok": True,
    "count": len(results),
    "issues": results,
}, indent=2))
PY
