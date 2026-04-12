# SDLC Do

Use this command for full delivery from plan through closeout with exactly two approval gates.

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

1. Normalize the work context into `.tmp`.
2. Build the plan in the command.
3. Gate 1 plan must include:
   - intended files or areas to modify
   - test strategy first
   - whether TDD is required, preferred, or not practical
   - verification plan
   - risks, assumptions, and dependencies
4. Prepare `inplace` or `worktree` execution context.
5. Write tests first whenever practical, then implement.
6. Run checks and tests.
7. Perform a code review pass in the command.
8. If checks, tests, or review fail, loop back through implementation.
9. Summarize diff and validate DOD.
10. Gate 2 presents exactly:
   - `Commit and merge.`
   - `Commit and push up as Pull Request.`
11. Finalize with the runtime script.

## Rules

- Exactly two approvals only.
- `inplace` means branch from trunk in the current worktree.
- `worktree` means isolated branch/worktree for parallel work.
- Planning, TDD judgment, review, and failure interpretation stay in the command.
- Deterministic execution belongs in `<workspace-root>/agentic-scripts`.
