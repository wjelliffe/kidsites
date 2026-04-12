---
name: sdlc-do
description: Use when a GitHub issue or direct request should be executed with a short-plan-first approach that escalates into a full two-gate SDLC delivery flow only when needed.
metadata:
  short-description: Definition of Done engine
---

# SDLC Do

Use this skill for implementation delivery from request through closeout.

Always start by proposing a minimal implementation plan. Execute only after intent is clear. Escalate into full SDLC rigor only when the work requires it.

## Use It When

- plain-language implementation requests that clearly match this workflow
- `/sdlc-do #62`
- `$sdlc-do #62` in Codex threads
- `/sdlc-do implement this request`
- `/sdlc-do #62 mode=worktree`
- `/sdlc-do #62 mode=inplace`

## Inputs

- GitHub issue number or direct freeform request
- Execution mode is optional. Default to `inplace`. Use `worktree` only when the user explicitly wants isolation.

Resolve `<workspace-root>` from the active repository, typically with `git rev-parse --show-toplevel`.

## Runtime References

Use `get_issue.sh` only when the input is a GitHub issue reference rather than a direct freeform request.

- `get_issue.sh`
- `prepare_sdlc_context.sh`
- `start_worktree.sh`
- `run_checks.sh`
- `run_tests.sh`
- `summarize_diff.sh`
- `validate_dod.sh`
- `finalize_work.sh`

## Gates

- Gate 1: approve the plan (only when full SDLC is triggered)
- Gate 2: approve the finished work before finalization

## Flow

### 0. Pre-Execution (Short Plan)

Propose the smallest meaningful implementation plan before touching the codebase.

The plan must be concise and practical:
- likely files to modify
- intended change
- minimal verification approach

Do not perform full context normalization.
Do not run `prepare_sdlc_context.sh`.
Do not generate full SDLC planning artifacts.

---

### Plan Outcome

#### If the plan is trivial and clearly correct:

- proceed directly to implementation
- do not require Gate 1
- begin execution

#### If the plan is unclear, risky, or non-trivial:

Escalate to full SDLC.

Triggers include:
- ambiguity in requirements
- multiple files or systems involved
- schema, API, auth, or deployment impact
- unclear verification strategy
- design decisions required

When escalating:
- briefly state why escalation is required
- proceed to Step 1

---

### Full SDLC Flow (only after escalation)

1. Normalize the work context into `.tmp`.
2. Build the plan in the skill.

3. Gate 1 plan must include:
   - intended files or areas to modify
   - test strategy first
   - whether TDD is required, preferred, or not practical
   - verification plan
   - risks, assumptions, and dependencies

4. Prepare `inplace` or `worktree` execution context.
5. Write tests first whenever practical, then implement.
6. Run checks and tests.
7. Perform a code review pass in the skill.
8. If checks, tests, or review fail, loop back through implementation.
9. Summarize diff and validate DOD.

---

### Finalization

10. Gate 2 presents exactly:
   - `Commit and merge.`
   - `Commit and push up as Pull Request.`

11. Finalize with the runtime script.

## Rules

- Always propose a plan before implementation.
- Do not modify the repository before intent is established.
- Use Gate 1 only when full SDLC flow is triggered.
- Use at most two approvals: Gate 1 (if escalated) and Gate 2 (finalization).
- `inplace` means branch from trunk in the current worktree.
- `worktree` means isolated branch/worktree for parallel work.
- Planning, TDD judgment, review, and failure interpretation stay in the skill.
- Deterministic execution belongs in `<workspace-root>/agentic-scripts`.
- Run `validate_dod.sh` only in full SDLC flow.
- Do not normalize the full work context into `.tmp` unless escalation occurs.
- In lightweight execution, prefer targeted verification over broad test runs.
- Do not broaden repository inspection beyond the smallest likely file set unless escalation conditions are met.