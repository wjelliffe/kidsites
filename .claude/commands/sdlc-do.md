# SDLC Do

Use this command for delivery from plan through closeout with a lightweight path for simple work and exactly two approval gates when the flow escalates.

## Use It When

- `/sdlc-do #62`
- `/sdlc-do implement this request`
- `/sdlc-do #62 mode=worktree`
- `/sdlc-do #62 mode=inplace`

## Inputs

- GitHub issue number or direct freeform request
- Execution mode is optional. Default to `inplace`. Use `worktree` only when the user explicitly wants isolation.

Resolve `<workspace-root>` from the active repository, typically with `git rev-parse --show-toplevel`.

## Runtime References

- `get_issue.sh`
- `prepare_sdlc_context.sh`
- `start_worktree.sh`
- `run_checks.sh`
- `run_tests.sh`
- `summarize_diff.sh`
- `validate_dod.sh`
- `finalize_work.sh`

## Gates

- Gate 1: approve the plan.
- Gate 2: approve the finished work before finalization.

## Flow

1. Propose the smallest meaningful implementation plan before touching the codebase.
2. If the plan is trivial and clearly correct:
   - proceed directly to implementation
   - do not require Gate 1
3. If the plan is unclear, risky, or non-trivial:
   - normalize the work context into `.tmp`
   - build the plan in the command
4. Gate 1 plan must include:
   - intended files or areas to modify
   - test strategy first
   - whether TDD is required, preferred, or not practical
   - verification plan
   - risks, assumptions, and dependencies
5. For issue-based epic execution:
   - treat the parent epic as orchestration-only
   - execute the child story issues
   - in `mode=worktree`, use one child worktree per child execution unit
6. Prepare `inplace` or `worktree` execution context for the actual execution unit.
7. Write tests first whenever practical, then implement.
8. Run checks and tests.
9. Perform a code review pass in the command.
10. If checks, tests, or review fail, loop back through implementation.
11. Summarize diff and validate DOD only when the flow escalated.
12. Gate 2 presents exactly:
   - `Commit and merge.`
   - `Commit and push up as Pull Request.`
13. Finalize with `finalize_work.sh`.
   - for issue-based work, use `finalize_work.sh` whenever the user asks to commit/finalize, including the lightweight path
   - "closing comment" means a commit or PR closing footer such as `Fixes #<issue>`, not a separate GitHub issue comment
   - do not call `gh issue close` or `gh issue comment` unless the user explicitly asks for that

Example:
- user says `commit with a closing comment`
- create the commit with `Fixes #<issue>` in the commit body
- do not post a GitHub comment or close the issue separately

## Rules

- Use Gate 1 only when the flow escalates.
- Use at most two approvals: Gate 1 when escalated, and Gate 2 for finalization.
- `inplace` means branch from trunk in the current worktree.
- `worktree` means isolated branch/worktree for parallel work.
- Planning, TDD judgment, review, and failure interpretation stay in the command.
- Deterministic execution belongs in `<workspace-root>/agentic-scripts`.
- For issue-based work, finalization goes through `finalize_work.sh` whenever the user asks to commit/finalize.
- "Closing comment" means a commit-body or PR-body closing footer such as `Fixes #<issue>` or `Closes #<issue>`.
- Do not call `gh issue close`, `gh issue comment`, or otherwise close/comment on the GitHub issue unless the user explicitly asks for that.
