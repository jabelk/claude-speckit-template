# Claude + Spec Kit Template

A reusable template for personal projects that use [Claude Code](https://claude.ai/claude-code) with [GitHub Spec Kit](https://github.com/github/spec-kit) for spec-driven development.

## What's Included

| Path | Purpose |
|------|---------|
| `CLAUDE.md` | Agent instructions: branching, testing, doc rules, spec-kit workflow, behavior guidelines |
| `AGENTS.md` | Agent read order, working rules, script references, common commands |
| `.specify/memory/constitution.md` | Skeleton constitution with placeholder principles, testing philosophy, quality gates |
| `.specify/memory/project-tracker.md` | Project state overview — points to GitHub Issues as primary tracker |
| `.specify/memory/lessons-learned/` | Index and storage for implementation lessons learned |
| `.specify/memory/complexity-budget.md` | LOC thresholds and dependency guardrails (delete if not needed) |
| `.specify/templates/` | Spec Kit templates (spec, plan, tasks, checklist, agent-file) |
| `.specify/scripts/bash/` | Spec Kit helper scripts (feature creation, plan setup, prerequisites, agent context) |
| `.claude/commands/speckit.*.md` | 9 slash commands for the specify → plan → tasks → implement workflow |
| `.gitignore` | Common ignores for Python, Node, Go, Rust |

## Quick Start

1. Click **"Use this template"** on GitHub (or clone and re-init)

2. Edit `CLAUDE.md` — replace the `{{PLACEHOLDERS}}` at the top:
   ```
   {{PROJECT_NAME}}        → Your project name
   {{PROJECT_DESCRIPTION}} → One-line description
   {{LANGUAGE}}            → e.g., Python, TypeScript, Go
   {{PACKAGE_MANAGER}}     → e.g., uv, npm, cargo
   ```

3. Fill in the command placeholders in `CLAUDE.md` and `AGENTS.md`:
   ```
   {{INSTALL_COMMAND}}     → e.g., uv sync, npm install
   {{TEST_COMMAND}}        → e.g., uv run pytest, npm test
   {{LINT_COMMAND}}        → e.g., uv run ruff check, npm run lint
   {{BUILD_COMMAND}}       → e.g., npm run build, cargo build
   {{DEV_COMMAND}}         → e.g., npm run dev, cargo run
   ```

4. Run `/speckit.constitution` in Claude Code to fill in your project's principles

5. Start building: `/speckit.specify <describe your first feature>`

## Workflow

```
/speckit.constitution  →  Set project principles (once)
/speckit.specify       →  Write feature spec
/speckit.clarify       →  Resolve ambiguities (optional)
/speckit.plan          →  Design implementation
/speckit.tasks         →  Break into ordered tasks
/speckit.analyze       →  Check consistency (optional)
/speckit.checklist     →  Validate requirements (optional)
/speckit.implement     →  Execute tasks (includes auto-PR and wrap-up)
/speckit.taskstoissues →  Convert tasks to GitHub Issues
```

## Work Tracking

This template uses **GitHub Issues as the primary tracker** — not parallel markdown files.

- Label issues with `feature`, `bug`, or `chore`
- Use milestones for release grouping
- Convert spec tasks to issues with `/speckit.taskstoissues`
- Close issues via PR references (`Closes #N`)

## Prerequisites

- [Claude Code](https://claude.ai/claude-code) CLI
- Git
- [GitHub CLI](https://cli.github.com/) (`gh`) — for issue tracking and PR creation
- [Spec Kit CLI](https://github.com/github/spec-kit) (optional, for `specify` commands):
  ```bash
  uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
  ```
