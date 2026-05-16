# Lessons Learned

Record implementation lessons here so future work avoids repeated mistakes.

## When to Read

- Before starting a new feature — scan the index for relevant topics.
- When hitting an unexpected issue — check if it's been seen before.

## When to Add

- After resolving a bug that took significant debugging time.
- When a design decision turned out to be wrong and was corrected.
- When an external dependency behaved unexpectedly.
- When a workaround was required and the reason isn't obvious from code.

## How to Add

Create a new file in this directory named after the topic (e.g., `auth-token-refresh.md`, `ci-timeout-flakes.md`). Then add it to the index below.

## Starter lessons (shipped with this template)

| File | Topic | Why it ships in the template |
|------|-------|------------------------------|
| `generation-qa-checklist.md` | Pre-delivery checklist for any Claude-generated artifact (docx/pptx/xlsx) — 8 categories of recurring failure mode | Strongly recommended as a Quality Gate in your project's constitution. Pairs with the Office skills install from `setup.sh`. |

## Index

| File | Topic | Date |
|------|-------|------|
<!-- Add entries as lessons are recorded. Example: -->
<!-- | `auth-token-refresh.md` | OAuth refresh tokens expire silently after 30 days | 2026-01-15 | -->
