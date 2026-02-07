# Claude + Spec Kit Template

A reusable template for personal projects that use [Claude Code](https://claude.ai/claude-code) with [GitHub Spec Kit](https://github.com/github/spec-kit) for spec-driven development.

## What's Included

| Path | Purpose |
|------|---------|
| `CLAUDE.md` | Agent instructions: branching strategy, doc rules, spec-kit workflow, behavior guidelines |
| `.specify/memory/constitution.md` | Skeleton constitution with placeholder principles |
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

3. Run `/speckit.constitution` in Claude Code to fill in your project's principles

4. Start building: `/speckit.specify <describe your first feature>`

## Workflow

```
/speckit.constitution  →  Set project principles (once)
/speckit.specify       →  Write feature spec
/speckit.clarify       →  Resolve ambiguities (optional)
/speckit.plan          →  Design implementation
/speckit.tasks         →  Break into ordered tasks
/speckit.analyze       →  Check consistency (optional)
/speckit.checklist     →  Validate requirements (optional)
/speckit.implement     →  Execute tasks
```

## Prerequisites

- [Claude Code](https://claude.ai/claude-code) CLI
- Git
- [Spec Kit CLI](https://github.com/github/spec-kit) (optional, for `specify` commands):
  ```bash
  uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
  ```
