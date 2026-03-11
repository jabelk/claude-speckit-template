# Project Tracker

## Quick Reference

| Field | Value |
|-------|-------|
| **Version** | 0.1.0 |
| **Stack** | [LANGUAGE / FRAMEWORK] |
| **Test coverage** | — |
| **Primary tracker** | [GitHub Issues](../../..) — use `gh issue list` |

## Tracking Convention

**GitHub Issues are the single source of truth for work tracking.**

- Label `feature` for new capabilities.
- Label `bug` for defects.
- Label `chore` for maintenance, refactoring, or tooling.
- Use milestones to group issues into releases or sprints.
- Reference issues in PRs with `Closes #N` to auto-close on merge.
- Use `/speckit.taskstoissues` to convert spec task breakdowns into issues.

Do **not** duplicate issue status in markdown files. If you need a quick view, run:

```bash
gh issue list --label feature --state open
gh issue list --label bug --state open
```

## Current State

<!-- One-paragraph description of where the project stands right now. -->
[PROJECT_STATE_DESCRIPTION]

## Known Issues & Gaps

<!-- Link to filtered GitHub Issues view, or note if none exist yet. -->
See `gh issue list --state open` for the current list.
