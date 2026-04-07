---
name: "feature"
description: "Start next feature — full workflow from issue triage through spec-driven development to shipping."
argument-hint: "Optionally specify an issue number or feature description"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "jabelk"
  source: "claude-code-template"
user-invocable: true
disable-model-invocation: true
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

## Phase 2: Research (do NOT skip this)

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

1. Run `/review-plan` — sends spec + plan to DeepSeek R1, OpenAI o4-mini, and Gemini 2.5 Flash for independent peer review
2. Present the GREEN/YELLOW/RED ratings and top issues to the user
3. If any RED: strongly recommend fixes; proceed only with explicit user approval
4. If any YELLOW: review with user and decide whether to fix first
5. If all providers are SKIPPED (missing API keys): flag to user, perform manual architectural review as fallback
6. Wait for user approval before moving to Phase 5

## Phase 5: Implement

1. Run `/speckit-implement` — execute tasks phase by phase
2. TDD where appropriate: write failing test first, then fix, then verify
3. **VERIFY BEFORE SHIPPING**: For any new library integration, read the actual installed source code and run a minimal working example BEFORE writing the full implementation
4. Clean up tests, docs, and code as you go — don't leave debt
5. Verify file-by-file after any bulk operations
6. Run lint and test commands after each phase

## Phase 6: Ship

1. Self-review the diff for: shell pipeline safety (`pipefail`), API keys in URLs, secrets/PII in external calls, doc consistency
2. Run tests — all must pass
3. `git diff --stat` — review, no unintended changes
4. Create PR against main
5. Address any CI/review findings before merging
6. Merge when approved
7. Verify deployment
