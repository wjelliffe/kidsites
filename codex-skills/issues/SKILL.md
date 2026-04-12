---
name: issues
description: Transform product or engineering input into clear, actionable GitHub issues using adaptive depth, conditional discovery, and a single approval gate.
metadata:
  short-description: PDLC to issue-definition engine
---

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

Apply only the depth required to make the work immediately actionable.

1. Inspect the input.
2. Classify as `epic`, `user_story`, `task`, or `bug` with default `user_story`.
3. Ask discovery questions only when they materially improve the issue definition.
4. Normalize the issue input into `.tmp`.
   - keep normalization lightweight for clear, single-issue requests
   - use the same deterministic normalized shape for every issue flow
5. Draft the issue or issue bundle:
   - bugs use the lean bug template
   - user stories, tasks, and bugs produce a single issue
   - epics produce a parent epic issue plus child story issues
   - keep DOR proportional to scope
6. Present the proposed issue(s).
7. Stop for the only gate:
   - `Proposed issue breakdown ready. Approve writing these issues.`
8. On approval, write the issue(s). Otherwise revise and re-present.

## Rules

- Keep discovery conditional.
- Keep DOR proportional to issue size and type.
- Deterministic work belongs in `<workspace-root>/agentic-scripts`.
- The only formal gate in this skill is approval to write the proposed issue(s).
- When drafting an epic with stories, create the stories as separate issues and attach them to the epic as GitHub sub-issues.
- Apply the minimum necessary structure to make the issue actionable; avoid over-expansion.
- Do not create multi-issue trees for bugs, tasks, or standalone user stories.
