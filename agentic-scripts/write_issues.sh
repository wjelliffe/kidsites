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
import re
import subprocess
import sys
import tempfile


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)


def fail(message, **extra):
    payload = {"ok": False, "error": message}
    payload.update(extra)
    print(json.dumps(payload, indent=2))
    sys.exit(1)


def read_repo():
    proc = run(["gh", "repo", "view", "--json", "nameWithOwner"])
    if proc.returncode != 0:
        fail("failed to resolve repository", stderr=proc.stderr.strip())
    data = json.loads(proc.stdout)
    name_with_owner = (data.get("nameWithOwner") or "").strip()
    if "/" not in name_with_owner:
        fail("repository nameWithOwner missing", response=data)
    owner, repo = name_with_owner.split("/", 1)
    return owner, repo


def create_issue(issue):
    with tempfile.NamedTemporaryFile("w", delete=False, encoding="utf-8") as tmp:
        tmp.write(issue["body"])
        tmp_path = tmp.name

    cmd = ["gh", "issue", "create", "--title", issue["title"], "--body-file", tmp_path]
    for label in issue.get("labels") or []:
        cmd.extend(["--label", label])
    proc = run(cmd)
    os.unlink(tmp_path)
    if proc.returncode != 0:
        fail(
            "failed to create issue",
            failed_title=issue["title"],
            stderr=proc.stderr.strip(),
        )

    url = proc.stdout.strip()
    match = re.search(r"/issues/(\d+)$", url)
    if not match:
        fail("failed to parse created issue number", failed_title=issue["title"], stdout=url)

    return {
        "key": issue.get("key"),
        "role": issue.get("role", "standalone"),
        "parent_key": issue.get("parent_key"),
        "title": issue["title"],
        "url": url,
        "number": int(match.group(1)),
        "labels": issue.get("labels") or [],
    }


def get_issue_id(owner, repo, issue_number):
    proc = run(["gh", "api", f"repos/{owner}/{repo}/issues/{issue_number}"])
    if proc.returncode != 0:
        fail(
            "failed to fetch created issue metadata",
            issue_number=issue_number,
            stderr=proc.stderr.strip(),
        )
    data = json.loads(proc.stdout)
    issue_id = data.get("id")
    if issue_id is None:
        fail("created issue metadata missing id", issue_number=issue_number, response=data)
    return issue_id


def attach_sub_issue(owner, repo, parent_number, sub_issue_id):
    proc = run([
        "gh",
        "api",
        "--method",
        "POST",
        f"repos/{owner}/{repo}/issues/{parent_number}/sub_issues",
        "-f",
        f"sub_issue_id={sub_issue_id}",
    ])
    if proc.returncode != 0:
        fail(
            "failed to attach sub-issue",
            parent_issue_number=parent_number,
            sub_issue_id=sub_issue_id,
            stderr=proc.stderr.strip(),
        )


with open(os.environ["BUNDLE_PATH"], "r", encoding="utf-8") as handle:
    payload = json.load(handle)

owner, repo = read_repo()
created_by_key = {}
results = []
for issue in payload.get("issues", []):
    created = create_issue(issue)
    created_by_key[created.get("key")] = created
    results.append(created)

for issue in results:
    if issue.get("role") != "sub_issue":
        continue
    parent = created_by_key.get(issue.get("parent_key"))
    if not parent:
        fail(
            "sub-issue parent was not created",
            sub_issue_title=issue["title"],
            parent_key=issue.get("parent_key"),
        )
    sub_issue_id = get_issue_id(owner, repo, issue["number"])
    attach_sub_issue(owner, repo, parent["number"], sub_issue_id)

print(json.dumps({
    "ok": True,
    "count": len(results),
    "issues": results,
}, indent=2))
PY
