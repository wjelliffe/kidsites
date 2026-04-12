# Issues

Turn rough product or engineering input into development-ready GitHub issue drafts.

## Use It When

- turning an epic, user story, task, or bug into clear issue draft(s)
- discovering missing requirements only when they matter
- preparing work so development can take the issue without more planning

## Inputs

Resolve `<workspace-root>` from the active repository, typically with `git rev-parse --show-toplevel`.

- current conversation context
- referenced local plan/spec files
- shared `.tmp` planning artifacts in the workspace
- issue JSON from `<workspace-root>/agentic-scripts/get_issue.sh`

## Runtime References

- `classify_issue_input.sh`
- `draft_issue_bundle.sh`
- `validate_dor.sh`
- `write_issues.sh`

## Flow

1. Inspect the input.
2. Classify as `epic`, `user_story`, `task`, or `bug` with default `user_story`.
3. Ask discovery questions only if they materially improve the issue definition.
4. Normalize the planning context into `.tmp`.
5. Draft the issue bundle and validate proportional DOR using the template appropriate to the issue type.
   - bugs should use the lean bug template
   - epics must produce a parent epic issue plus explicit child story issues in the bundle
6. Present the proposed issue breakdown.
7. Stop for the only gate:
   - `Proposed issue breakdown ready. Approve writing these issues.`
8. On approval, write the issue(s). Otherwise revise and re-present.

## Rules

- Keep discovery conditional.
- Keep DOR proportional to issue size and type.
- Deterministic work belongs in `<workspace-root>/agentic-scripts`.
- The only formal gate in this skill is approval to write the proposed issue(s).
- When drafting an epic with stories, create the stories as separate issues and attach them to the epic as GitHub sub-issues.
