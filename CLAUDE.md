# {{PROJECT_NAME}}

{{PROJECT_DESCRIPTION}}

## Tech Stack

<!-- Replace with your project's tech stack -->
- {{LANGUAGE}} (managed with {{PACKAGE_MANAGER}})

## Common Commands

<!-- Replace placeholders with your project's actual commands -->

| Action | Command |
|--------|---------|
| Install dependencies | `{{INSTALL_COMMAND}}` |
| Run tests | `{{TEST_COMMAND}}` |
| Run linter | `{{LINT_COMMAND}}` |
| Build | `{{BUILD_COMMAND}}` |
| Run dev server | `{{DEV_COMMAND}}` |

## Environment Variables

<!-- If your project uses environment variables, maintain a `.env.example` file at the repo root -->
See `.env.example` for required environment variables (if applicable).

## Branching Strategy

- **Never commit directly to `main`.**
- **Never force push.** If history needs rewriting, discuss first.
- **Always create a pull request** for every change merged to `main`.
- For each unit of work (feature, fix, refactor), create a new branch off `main`:
  - Format: `<short-description>` (e.g., `add-episode-parser`, `fix-url-handling`)
- When work is complete, create a pull request against `main` with a summary of what was done.
- Merge the PR (squash or merge commit, no rebase) to keep a clean paper trail.
- **Delete the feature branch after merge.**

## Testing & Verification

The project's testing philosophy is defined in `.specify/memory/constitution.md` (see Testing Philosophy and Quality Gates sections). In short:

- Write tests before implementation (TDD).
- All tests must pass before committing or merging.
- No secrets or credentials in code or commits.

### Post-Implementation Checklist

- [ ] All acceptance criteria from the spec are covered by tests
- [ ] Tests pass locally (`{{TEST_COMMAND}}`)
- [ ] Linter is clean (`{{LINT_COMMAND}}`)
- [ ] No secrets, API keys, or credentials in the diff
- [ ] PR description references the spec and summarizes changes

## Documentation Strategy

There are two documentation audiences. Keep them separate.

### For Agents: `.specify/` (source of truth)

All design decisions, specs, plans, and task tracking live here. This is the **primary reference for Claude and other coding agents**. Before making implementation decisions, always consult the relevant `.specify/` files.

**Directory structure:**

| Path | Purpose | When to update |
|------|---------|----------------|
| `.specify/memory/constitution.md` | Non-negotiable project principles. All work must comply. | Rarely — only when principles change. |
| `.specify/memory/project-tracker.md` | Project state overview and pointer to GitHub Issues. | When milestones or stack change. |
| `.specify/memory/lessons-learned/` | Lessons learned from implementation. | After resolving unexpected issues. |
| `specs/<feature>/spec.md` | What to build. User stories, requirements, acceptance criteria. | Created via `/speckit-specify`, updated if requirements change. |
| `specs/<feature>/plan.md` | How to build it. Tech choices, architecture, project structure. | Created via `/speckit-plan`, updated if approach changes. |
| `specs/<feature>/tasks.md` | Ordered task breakdown with dependencies and checkpoints. | Created via `/speckit-tasks`, checked off during implementation. |
| `specs/<feature>/research.md` | Phase 0 research output (dependencies, alternatives). | Created during `/speckit-plan`. |
| `specs/<feature>/data-model.md` | Entity definitions and relationships. | Created during `/speckit-plan`. |
| `specs/<feature>/contracts/` | API contracts, interfaces. | Created during `/speckit-plan`. |
| `.specify/templates/` | Templates used by spec-kit. Do not edit directly. | Never — managed by spec-kit. |
| `.specify/scripts/` | Helper scripts for spec-kit. Do not edit directly. | Never — managed by spec-kit. |

### For Humans: `docs/` and `README.md`

High-level documentation for human readers lives in `docs/` and the repo `README.md`.

- `README.md` — Project overview, how to install, how to run, quick examples.
- `docs/` — Architecture overview, design rationale, usage guides. Written in plain language for a human audience.

### Rules for Documentation Updates

1. **Do not create markdown files outside of `.specify/`, `docs/`, or `README.md`** unless explicitly asked.
2. **Do not proactively generate or rewrite docs.** Only update docs when: (a) the user asks, or (b) a spec-kit command requires it.
3. **Keep updates surgical.** When updating a `.specify/` file, edit the specific section that changed — do not regenerate the entire file.
4. **Spec files are append/edit, not rewrite.** If a plan or spec exists, update it incrementally. Do not overwrite prior decisions without discussion.

## Tracking Work

- **GitHub Issues are the primary tracker.** Use labels: `feature` for new work, `bug` for defects.
- Use `/speckit-taskstoissues` to convert spec tasks into GitHub Issues.
- Close issues via PR references (e.g., `Closes #12`) — do not close manually unless no code change is needed.

## Spec-Driven Development Workflow

This project uses [GitHub Spec Kit](https://github.com/github/spec-kit). The workflow is:

1. `/speckit-constitution` — Establish project principles (done once, lives in `.specify/memory/constitution.md`)
2. `/speckit-specify` — Write the specification for a feature
3. `/speckit-plan` — Create the implementation plan
4. `/speckit-tasks` — Break the plan into ordered tasks
5. `/review-plan` — Multi-model peer review (OpenAI o4-mini, Gemini 2.5 Flash)
6. `/speckit-implement` — Execute tasks

**Use `/feature` to run the full workflow end-to-end** — it orchestrates all steps in order with research and review gates.

**Before writing any code**, check that a spec and plan exist for the work. If they don't, raise it with the user.

## Agent Behavior Guidelines

- **Always read `.specify/memory/constitution.md` before starting a new feature** to ensure compliance with project principles.
- **Always read the relevant `specs/<feature>/` files before implementing** to understand the design decisions already made.
- **Do not skip the spec-kit workflow.** If asked to build something new, suggest running through specify → plan → tasks → implement.
- **Commit after each logical unit of work**, not after every single file change.
- **When in doubt about a design decision**, check the spec and plan first, then ask the user.
- **Verify before shipping**: For any new library integration, read the actual installed source code and run a minimal working example BEFORE writing the full implementation.

## Related Documentation

| Document | Purpose |
|----------|---------|
| `.specify/memory/constitution.md` | Project principles, testing philosophy, quality gates |
| `.specify/memory/project-tracker.md` | Current project state, pointer to GitHub Issues |
| `.specify/memory/lessons-learned/` | Lessons learned index and topic files |
| `AGENTS.md` | Agent-specific workflow guide and read order |
| `specs/` | Feature specifications, plans, and tasks |

## Active Technologies
<!-- Updated automatically by spec-kit during /speckit-plan -->

## Recent Changes
<!-- Updated automatically by spec-kit during /speckit-plan -->
