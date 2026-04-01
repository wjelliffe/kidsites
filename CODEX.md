# CODEX.md

Generic project guidance for OpenAI Codex.

## Operating Principles
- Propose -> approve -> edit.
- Keep changes minimal and reversible.
- Communicate assumptions and risks clearly.

## Standard SDLC
- Start branch
- Pull issue context
- Update docs/specs
- Implement scoped changes
- Commit with issue reference
- Ship via PR

## Safety
- Do not run destructive commands unless explicitly requested.
- Do not run installs/tests unless approved.

## Automation
Slash-command specs are defined in `.claude/commands`.

