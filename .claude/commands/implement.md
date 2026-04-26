# Implement

Execute a single implementation unit with minimal overhead.

Default to direct execution. Treat the issue or request as the plan. Touch the fewest files possible.

---

## Scope

Supports:
- one GitHub issue
- one direct request

Does NOT support:
- epics
- multiple issues
- orchestration
- sub-agents

If multiple issues or an epic are detected, STOP and say:

`This skill only supports single issue execution.`

---

## Inputs

- GitHub issue OR direct request

---

## Runtime Scripts

- `get_issue.sh`
- `run_checks.sh`
- `run_tests.sh`
- `summarize_diff.sh`
- `finalize_work.sh`

Do NOT use:
- `prepare_sdlc_context.sh`
- `validate_dod.sh`
- `start_worktree.sh`

---

## Flow

### 0. Load (if issue)

If input is a GitHub issue:
- run `get_issue.sh`

If it fails:
- STOP and report failure

---

### 1. Execution Preview

Provide a very short preview:

- likely files
- intended change
- minimal verification

Do not wait for approval.

---

### 2. Implementation

- implement directly
- keep changes minimal and targeted
- do not expand scope

---

### 3. Validation

Run:
- `run_checks.sh`

If checks fail:
- STOP and report failure

Run `run_tests.sh` ONLY if:
- relevant tests already exist OR
- the issue explicitly requires tests

If tests fail:
- STOP and report failure

---

### 4. Diff Summary

Run:
- `summarize_diff.sh`

Present:

- files changed
- what was done
- verification results
- known risks or follow-ups

---

### 5. Final Approval / Review Gate

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
- rerun `/code-review` if appropriate
- then present exactly:

- `Commit and merge.`
- `Commit and push up as Pull Request.`

---

### 6. Finalization

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

- No plan approval gate
- No SDLC escalation
- No retry loops (fail once → stop)
- No full context normalization
- No in-skill review
- Use targeted verification only
- Keep output concise
- Do not modify unrelated files
- Do not continue after any failure