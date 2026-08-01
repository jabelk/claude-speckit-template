---
name: "feature"
description: "Start next feature — full workflow from issue triage through spec-driven development to shipping."
argument-hint: "Optionally specify an issue number or feature description"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "jabelk"
  source: "claude-code-template"
user-invocable: true
---

# Start Next Feature

Full workflow from issue triage to implementation. Do NOT skip steps.

## Phase 1: Orient (always do this first)

1. Read `CLAUDE.md` and `.specify/memory/constitution.md` to refresh context
2. Read `MEMORY.md` for project status, user preferences, and active work
3. Run `gh issue list --state open --limit 30` to see the current backlog
4. Run `git log --oneline -10` to see recent work
5. Present a summary: "Here's where we are, here's what's open, here's what I'd recommend next"
6. Wait for user input on which issue(s) to tackle

## Phase 2: Re-orient + Research (do NOT skip this)

### Codebase re-orientation (mandatory)

CLAUDE.md, MEMORY.md, and the constitution are curated pointers — they go stale; the code is the source of truth. Before specifying or planning, spawn an Explore agent over the subsystem(s) the feature touches (schema, services, routes, components). Have it report:

- the current data model and existing machinery that overlaps the feature (prior art to reuse)
- corrections to any assumption stated in the feature request, memory files, or the conversation so far

Feed those corrections into the spec. Never plan from memory files alone — stale architecture claims poison the planning phase.

### Online research

Before specifying or planning, research online:
- Are there better approaches than the obvious one?
- What do competitors/similar projects do?
- Any libraries, APIs, or patterns that would save time?
- Check if the approach has known pitfalls

Present findings to user. This step has repeatedly prevented bad architectural decisions.

## Phase 3: Specify

1. Run `/speckit-specify` with the feature description
2. This creates the branch and spec automatically
3. Review for plot holes, missing edge cases, unclear requirements
4. Wait for user feedback before proceeding

## Phase 4: Plan + Tasks

1. Run `/speckit-plan` — research decisions, data model, architecture
2. Run `/speckit-tasks` — task breakdown with dependencies
3. If anything needs clarification, run `/speckit-clarify`
4. If quality check needed, run `/speckit-analyze`

## Phase 4.5: Review (do NOT skip this)

1. Run `/review-plan` — sends spec + plan to OpenAI gpt-5.3-codex and Gemini 2.5 Pro for independent peer review
2. The script outputs raw text from each model — you must read the output and interpret the GREEN/YELLOW/RED ratings manually
3. Present all three reviews to the user with a summary
4. If any RED: strongly recommend fixes; proceed only with explicit user approval
5. If any YELLOW: review with user and decide whether to fix first
6. If all providers are SKIPPED (missing API keys): flag to user, perform manual architectural review as fallback
7. Wait for user approval before moving to Phase 5

## Phase 5: Implement

1. Run `/speckit-implement` — execute tasks phase by phase
2. TDD where appropriate: write failing test first, then fix, then verify
3. **VERIFY BEFORE SHIPPING**: For any new library integration, read the actual installed source code and run a minimal working example BEFORE writing the full implementation
4. Clean up tests, docs, and code as you go — don't leave debt
5. Verify file-by-file after any bulk operations
6. Run lint and test commands after each phase

## Phase 6: Ship

1. **Self-review the diff — CodeRabbit-style pass.** Walk the diff against these patterns before opening the PR. Each round of CR review costs 10-20 min of user attention — catch these yourself:
   - **try/except scope**: covers *all* error-raising paths, including early-return branches (not just the happy path)
   - **Leaked secrets/URLs in logs**: signed URLs, tokens, API keys, PII in debug/log statements
   - **Vacuous tests**: tests that pass regardless of the code under test (e.g. `assert True`, assertions on empty response bodies); assert user-visible state, not just request shapes
   - **Missing edge cases**: empty collections, None/null, timezone boundaries, idempotency on retry paths
   - **Duplicated magic constants**: same value in two files → extract a helper
   - **Shell pipeline safety**: `set -euo pipefail` in scripts, API keys in URLs, secrets/PII in external calls
   - **Doc consistency**: README / CLAUDE.md / specs still match the code
2. Run tests — all must pass
3. `git diff --stat` — review, no unintended changes
4. Create PR against main
5. Address any CI/review findings before merging
6. Merge when approved
7. Verify deployment
