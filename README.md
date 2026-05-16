# Claude Code Template

A reusable project template for [Claude Code](https://claude.ai/claude-code) with [GitHub Spec Kit](https://github.com/github/spec-kit) for spec-driven development and multi-model plan review.

## What's Included

| Component | Source | Purpose |
|-----------|--------|---------|
| `CLAUDE.md` | Template | Project instructions for Claude (fill in placeholders) |
| `AGENTS.md` | Template | Agent workflow guide and read order |
| `.specify/` | Spec Kit (dependency) | Scripts, templates, and memory for spec-driven development |
| `.claude/skills/speckit-*` | Spec Kit (dependency) | Spec-driven development commands |
| `.claude/skills/feature/` | Custom | Full workflow orchestrator (orient, research, specify, plan, review, implement, ship) |
| `.claude/skills/review-plan/` | Custom | Multi-model peer review gate |
| `scripts/review-plan.sh` | Custom | Sends plans to OpenAI gpt-5.3-codex, Gemini 2.5 Pro for peer review |
| `scripts/install_office_skills.sh` | Custom | Installs Anthropic's official `docx` / `pptx` / `xlsx` skills so Claude Code can generate Word, PowerPoint, and Excel artifacts directly. Re-fetches from upstream (skills are non-redistributable per their LICENSE.txt). |
| `setup.sh` | Template | Bootstrap script — installs/upgrades spec-kit dependency, runs Office skills install, updates `.gitignore` |

## Quick Start

1. **Create your project** — one command:
   ```bash
   curl -sL https://raw.githubusercontent.com/jabelk/claude-speckit-template/main/scripts/new-project.sh | bash -s my-project
   ```
   This clones the template, strips git history, inits a fresh repo, and runs `setup.sh` to pull latest spec-kit — all in one step.
3. **Edit `CLAUDE.md`** — replace `{{PLACEHOLDERS}}` with your project details:
   ```
   {{PROJECT_NAME}}        → Your project name
   {{PROJECT_DESCRIPTION}} → One-line description
   {{LANGUAGE}}            → e.g., Python, TypeScript, Go
   {{PACKAGE_MANAGER}}     → e.g., uv, npm, cargo
   {{INSTALL_COMMAND}}     → e.g., uv sync, npm install
   {{TEST_COMMAND}}        → e.g., uv run pytest, npm test
   {{LINT_COMMAND}}        → e.g., uv run ruff check, npm run lint
   {{BUILD_COMMAND}}       → e.g., npm run build, cargo build
   {{DEV_COMMAND}}         → e.g., npm run dev, cargo run
   ```
4. **Set up API keys** for multi-model review (optional):
   ```bash
   cp .env.example .env
   # Add your API keys
   ```
5. **Start Claude Code and run:**
   ```
   /speckit-constitution   # Establish project principles (once)
   /feature                # Start your first feature
   ```

## Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) (or Claude Code desktop/web)
- [Git](https://git-scm.com/)
- [GitHub CLI](https://cli.github.com/) (`gh`)
- [uv](https://docs.astral.sh/uv/) (Python package manager, for spec-kit CLI)

## Workflow

The `/feature` skill orchestrates the full development lifecycle:

```
Phase 1: Orient     → Read context, check backlog, recommend next work
Phase 2: Research   → Online research before committing to an approach
Phase 3: Specify    → /speckit-specify — write the feature spec
Phase 4: Plan       → /speckit-plan + /speckit-tasks — architecture + task breakdown
Phase 4.5: Review   → /review-plan — multi-model peer review (GREEN/YELLOW/RED)
Phase 5: Implement  → /speckit-implement — TDD execution
Phase 6: Ship       → Tests, PR, merge, deploy
```

## Updating Spec Kit

Spec Kit is installed as a dependency via `specify init`, not vendored as frozen copies. To pull the latest version:

```bash
./setup.sh
```

This upgrades the `specify` CLI and re-runs `specify init` to update scripts, templates, and commands while preserving your custom skills and project files.

## Work Tracking

This template uses **GitHub Issues as the primary tracker** — not parallel markdown files.

- Label issues with `feature`, `bug`, or `chore`
- Use milestones for release grouping
- Convert spec tasks to issues with `/speckit-taskstoissues`
- Close issues via PR references (`Closes #N`)

## Office Artifacts (Word / PowerPoint / Excel)

`setup.sh` installs Anthropic's official `docx`, `pptx`, and `xlsx` skills into `.claude/skills/`. After setup, Claude Code can generate Office files directly when asked — useful for status reports, mgmt decks, spreadsheets that summarize work.

**How to use**:

```
You: "Generate a status report Word doc from the last 5 commits."
You: "Build me a 10-slide deck explaining this feature for non-technical stakeholders."
You: "Make an Excel workbook with the test-coverage numbers from the last 3 sprints."
```

The skills auto-invoke based on keywords (`Word doc`, `.docx`, `slides`, `deck`, `presentation`, `spreadsheet`, `.xlsx`, etc.).

**Quality**: the skills include validation patterns + a fix-and-verify QA loop that mirrors claude.ai's output quality. For visual QA on slides, install LibreOffice:

```bash
brew install --cask libreoffice
```

Without LibreOffice, content QA still works; visual QA (slide thumbnails, layout checks) is disabled.

**Why the skills aren't vendored**: Anthropic's `LICENSE.txt` for these skills explicitly prohibits redistribution and retaining copies outside Anthropic Services. The compliant pattern is to re-fetch them from `github.com/anthropics/skills` at install time. `setup.sh` does this; `.gitignore` excludes `.claude/skills/{docx,pptx,xlsx}/` so they never get committed.

**Re-running**: `scripts/install_office_skills.sh` is re-runnable; it refreshes the cached upstream clone and reinstalls. Worth running occasionally to pick up skill updates from Anthropic.

## Customization

### review-plan.sh

Edit the `SYSTEM_PROMPT` in `scripts/review-plan.sh` to add framework-specific review focus areas. For example:

```
6. FRAMEWORK GOTCHAS: SvelteKit/Svelte 5 specific issues ($derived tracking, rune file restrictions)
```

### Adding Skills

Add new skills in `.claude/skills/<skill-name>/SKILL.md`. See existing skills for the frontmatter format.
