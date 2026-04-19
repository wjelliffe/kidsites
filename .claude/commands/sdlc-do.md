# SDLC Do

Execute exactly one implementation unit from plan through finalization.

## Scope Constraints

This skill supports:
- one GitHub issue
- one direct request

This skill does NOT support:
- epics
- parent issues with children
- multiple issues
- orchestration
- sub-agents

If an epic or multiple issues are detected, STOP and say:

`This skill only supports single issue execution. Epics are not supported.`

---

## Inputs

- GitHub issue OR direct request
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
- run `get_issue.sh`

Then:
- run `prepare_sdlc_context.sh`

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
- run `start_worktree.sh`

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
- `validate_dod.sh`

If either fails:
- STOP and report failure

---

### 6. Gate 2

Present exactly:

- `Commit and merge.`
- `Commit and push up as Pull Request.`

Wait for user selection.

---

### 7. Finalization

Run:
- `finalize_work.sh`

Rules:
- include closing footer if issue-based (`Fixes #<issue>`)
- do NOT manually run git commands
- do NOT call GitHub APIs directly

If finalization fails:
- STOP and report failure

---

## Rules

- Always require Gate 1 and Gate 2
- No retry loops: fail once → stop
- No epic handling
- No child issue execution
- No sub-agents
- No orchestration
- Keep planning minimal
- Keep execution tight
- Keep validation lightweight
- Deterministic work belongs in scripts only
- Do not broaden scope beyond the issue
- Do not modify unrelated files
- Do not continue after any failure
- Do not auto-retry anything