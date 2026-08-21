# Agent Guide

Instructions for Claude and other coding agents working in this repository.

## Read Order

Read these files in order before starting work. Higher priority files take precedence when conflicts arise.

| Priority | File | Purpose |
|----------|------|---------|
| 1 | `CLAUDE.md` | Project setup, commands, branching rules |
| 2 | `.specify/memory/constitution.md` | Non-negotiable principles, testing philosophy, quality gates |
| 3 | `.specify/memory/project-tracker.md` | Current project state, pointer to GitHub Issues |
| 4 | `.specify/memory/lessons-learned/` | Past mistakes to avoid repeating |
| 5 | `specs/<feature>/` | Spec, plan, and tasks for the current feature |

## Working Rules

1. **No direct commits to `main`.** Always use a feature branch and PR.
2. **No secrets in code or commits.** Check diffs before committing.
3. **Check specs before coding.** If `specs/<feature>/` exists, read it. If it doesn't, suggest creating one.
4. **GitHub Issues are the primary tracker.** Don't duplicate issue tracking in markdown. Use labels: `feature`, `bug`, `chore`.
5. **Follow quality gates.** Tests pass + linter clean before every commit.
6. **`.specify/extensions.yml` is a trust boundary.** The speckit skills read it and will surface — and for `optional: false` entries, auto-execute — whatever commands it registers. Review any change to it like executable code; this fleet keeps every hook `optional: true`.

## Spec Kit Workflow

Use `/feature` to run the full workflow end-to-end, or use individual commands:

```text
/speckit-constitution  →  Set project principles (once)
/speckit-specify       →  Write feature spec
/speckit-clarify       →  Resolve ambiguities (optional)
/speckit-plan          →  Design implementation
/speckit-tasks         →  Break into ordered tasks
/review-plan           →  Multi-model peer review (before implementing)
/speckit-analyze       →  Check consistency (optional)
/speckit-checklist     →  Validate requirements (optional)
/speckit-implement     →  Execute tasks
/speckit-taskstoissues →  Convert tasks to GitHub Issues
```

### Script References

| Script | Purpose | Example |
|--------|---------|---------|
| `create-new-feature.sh` | Scaffold `specs/NNN-name/spec.md` and select it via `SPECIFY_FEATURE` (since spec-kit v1 it no longer checks out a git branch — branch separately per the rules above) | `.specify/scripts/bash/create-new-feature.sh --json --short-name add-auth "Add auth"` |
| `setup-plan.sh` | Initialize plan from spec | `.specify/scripts/bash/setup-plan.sh` |
| `check-prerequisites.sh` | Validate feature status | `.specify/scripts/bash/check-prerequisites.sh --json` |
| `update-agent-context.sh` | Refresh agent context | `.specify/scripts/bash/update-agent-context.sh` |
| `review-plan.sh` | Multi-model peer review | `./scripts/review-plan.sh [specs/003-feature-name]` |

## Common Commands

<!-- Replace placeholders with your project's actual commands -->

| Action | Command |
|--------|---------|
| Install dependencies | `{{INSTALL_COMMAND}}` |
| Run tests | `{{TEST_COMMAND}}` |
| Run linter | `{{LINT_COMMAND}}` |
| List open issues | `gh issue list --state open` |
| List bugs | `gh issue list --label bug --state open` |
| List features | `gh issue list --label feature --state open` |
