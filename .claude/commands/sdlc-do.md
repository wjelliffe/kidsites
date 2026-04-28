# SDLC Do

Execute exactly one bounded implementation unit from plan through finalization.

## Scope Constraints

This skill supports:
- one GitHub issue
- one grouped set of closely related GitHub issues delivered as one unit
- one direct request

This skill does NOT support:
- epics
- parent issues with children
- unrelated issue batching
- orchestration
- sub-agents

Grouped issues are allowed only when they are a single logical delivery unit:
- same code path or shared acceptance surface
- intended to land in one commit/PR
- small enough to plan, validate, and review together
- not an epic, parent issue, or orchestration request

If the request is an epic, a parent issue with children, or unrelated batching, STOP and say:

`This skill only supports one bounded implementation unit. Epics and unrelated issue batching are not supported.`

---

## Inputs

- GitHub issue, grouped issue set, OR direct request
- Optional: `mode=inplace` (default) or `mode=worktree`

Resolve `<workspace-root>` via: --- git rev-parse –show-toplevel

## Runtime Scripts

- `get_issue.sh`
- `prepare_sdlc_context.sh`
- `start_worktree.sh`
- `run_checks.sh`
- `run_tests.sh`
- `summarize_diff.sh`
- `validate_dod.sh`
- `finalize_work.sh`

---

## Gates

- **Gate 1**: Plan approval (always required)
- **Gate 2**: Final approval before commit

---

## Flow

### 0. Load Context

If input is an issue:
- run `get_issue.sh <issue-number>` and capture the normalized issue json `path`
- if the request is a grouped issue set, pass every issue number in one call to `get_issue.sh` and capture the normalized issue json `path`

Then:
- run `prepare_sdlc_context.sh issue <issue-json-path>` and capture the SDLC context `path`

If input is a direct request:
- run `prepare_sdlc_context.sh request` with the request on stdin and capture the SDLC context `path`

If either fails:
- STOP and report failure

---

### 1. Plan (Gate 1)

Produce a minimal, execution-focused plan:

- files to modify
- intended changes
- test strategy FIRST
- TDD stance (required / preferred / not practical)
- verification plan
- risks / assumptions

Then stop and request approval.

---

### 2. Execution Setup

If `mode=worktree`:
- run `start_worktree.sh <work-key> worktree <context-json-path>`

If `mode=inplace`:
- run `start_worktree.sh <work-key> inplace <context-json-path>`

If setup fails:
- STOP and report failure

---

### 3. Implementation

- write tests first when practical
- implement changes
- keep scope tightly bound to plan

---

### 4. Validation

Run:
- `run_checks.sh`
- `run_tests.sh`

If either fails:
- STOP and report failure

---

### 5. Diff + DoD

Run:
- `summarize_diff.sh`
- `validate_dod.sh <context-json-path> <checks-json-path> <tests-json-path>`

If either fails:
- STOP and report failure

---

### 6. Gate 2

Present exactly:

- `Execute code review.`
- `Commit and merge.`
- `Commit and push up as Pull Request.`

Wait for user selection.

If the user selects `Execute code review.`, invoke `/code-review`.

If `/code-review` returns `APPROVE`, present exactly:

- `Commit and merge.`
- `Commit and push up as Pull Request.`

If `/code-review` returns `BLOCKERS`, stop before finalization and iterate with the user until the priority review findings are fixed.

After fixing review blockers:
- rerun validation as needed
- rerun Diff + DoD if needed
- rerun `/code-review` if appropriate
- then present exactly:

- `Commit and merge.`
- `Commit and push up as Pull Request.`

---

### 7. Finalization

Run:
- `finalize_work.sh merge <context-json-path>` when the user selected `Commit and merge.`
- `finalize_work.sh pr <context-json-path>` when the user selected `Commit and push up as Pull Request.`

Rules:
- include closing footer for every issue-based reference (`Fixes #<issue>`)
- do NOT manually run git commands
- do NOT call GitHub APIs directly

If finalization fails:
- STOP and report failure

---

## Rules

- Always require Gate 1 and Gate 2
- No retry loops: fail once → stop
- No epic handling
- Child issue execution is supported
- Do not execute parent issues
- No sub-agents
- No orchestration
- Keep planning minimal
- Keep execution tight
- Keep validation lightweight
- Deterministic work belongs in scripts only
- Do not broaden scope beyond the bounded implementation unit
- Do not modify unrelated files
- Do not continue after any failure
- Do not auto-retry anything
