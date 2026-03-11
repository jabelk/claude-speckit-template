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

## Spec Kit Workflow

Use these slash commands in order:

```
/speckit.constitution  →  Set project principles (once)
/speckit.specify       →  Write feature spec
/speckit.clarify       →  Resolve ambiguities (optional)
/speckit.plan          →  Design implementation
/speckit.tasks         →  Break into ordered tasks
/speckit.analyze       →  Check consistency (optional)
/speckit.checklist     →  Validate requirements (optional)
/speckit.implement     →  Execute tasks
/speckit.taskstoissues →  Convert tasks to GitHub Issues
```

### Script References

| Script | Purpose | Example |
|--------|---------|---------|
| `create-new-feature.sh` | Create feature branch + spec file | `.specify/scripts/bash/create-new-feature.sh --short-name add-auth` |
| `setup-plan.sh` | Initialize plan from spec | `.specify/scripts/bash/setup-plan.sh` |
| `check-prerequisites.sh` | Validate feature status | `.specify/scripts/bash/check-prerequisites.sh --json` |
| `update-agent-context.sh` | Refresh agent context | `.specify/scripts/bash/update-agent-context.sh` |

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
