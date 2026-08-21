---
name: "ship"
description: "Ship the current change: CodeRabbit-style self-review, unpiped gates, PR, batched review round, merge, per-project promote/verify. The shipping half of /feature, usable standalone for small fixes."
argument-hint: "Optionally describe the change being shipped"
compatibility: "Git repo with a remote, a PR system (GitHub), and CI; promote/verify steps are read from the project's CLAUDE.md (stops at merge if none defined)"
metadata:
  author: "jabelk"
  source: "claude-code-template"
user-invocable: true
disable-model-invocation: true
---

# Ship

Drive the current change from working tree to merged — and promoted, where the project defines a pipeline. Two entry paths, identical steps:

- **Standalone** (`/ship`): small fixes and chores that don't need the spec ceremony.
- **From `/feature`**: Phase 6 delegates here. Shipping mechanics live in THIS skill only — if shipping behavior needs to change, change it here, not in `/feature`.

## Phase 0: Preflight

1. Never ship from `main`, `staging`, or any long-lived branch. If you're on one, create a `fix/` or `chore/` branch first.
2. Standalone bug fixes are TDD: write the FAILING test first, confirm it fails, then fix. Skip only for pure docs/config changes — and say you skipped it.

## Phase 1: Self-review the diff — CodeRabbit-style pass

Walk the diff against these patterns before opening the PR. Each PR-side review round costs real user attention — catch these yourself:

- **try/except scope**: covers *all* error-raising paths, including early-return branches (not just the happy path)
- **Leaked secrets/URLs in logs**: signed URLs, tokens, API keys, PII in debug/log statements
- **Vacuous tests**: tests that pass regardless of the code under test (e.g. `assert True`, assertions on empty response bodies); assert user-visible state, not just request shapes
- **Missing edge cases**: empty collections, None/null, timezone boundaries, idempotency on retry paths
- **Duplicated magic constants**: same value in two files → extract a helper
- **Shell pipeline safety**: `set -euo pipefail` in scripts, API keys in URLs, secrets/PII in external calls
- **Doc consistency**: README / CLAUDE.md / specs still match the code

## Phase 2: Gates — unpiped

1. Run the project's lint, format, and test commands as SEPARATE, UNPIPED commands. Pipes mask exit codes — a `cmd | tail` that "passed" has shipped red CI before. If piping is unavoidable, `set -o pipefail` or check `${PIPESTATUS[0]}`. Every gate must exit 0.
2. `git status --short` and `git diff HEAD --stat` — the plain `git diff` misses staged and untracked files; confirm no unintended changes anywhere in the tree.
3. If a local review CLI is available (`review-plan-v2`, `coderabbit`), run it against the base branch and address its findings now — the PR-side review is the safety net, not the first pass.

## Phase 3: Commit + PR

1. Stage and commit the change (`git push` sends commits, not working-tree edits — standalone `/ship` starts from an uncommitted tree). Verify the tree is clean after committing.
2. Push the branch and open a PR against the project's default branch.
3. Wait for CI green. Poll on a paced loop; don't block synchronously.

## Phase 4: Review round — batched

1. Enumerate EVERY unresolved review comment (CodeRabbit and human) in a table first: comment | real bug? (yes/no, one-line why) | planned fix.
2. Fix all the real ones in ONE commit. Decline the rest with a brief stated reason (vendored content, intentional style, out of scope).
3. Before pushing the batch, re-run the tests covering behaviors fixed in EARLIER rounds of this PR — hardening passes have regressed prior fixes before.
4. Iterate only on genuinely new findings. Round 3+ is a signal something upstream is wrong (missing local review pass, config drift) — surface it instead of grinding.

## Phase 5: Merge, promote, prove

1. Merge when CI is green, no actionable threads remain, AND the repo's merge requirements are satisfied — check mergeable state, required human approvals, and branch-protection rules; green CI alone does not prove mergeability. Squash unless the repo prefers otherwise. NEVER delete branches — feature branches are preserved, and long-lived branches (`main`, `staging`) must never be deleted.
2. Read the project's CLAUDE.md for its promote/verify pipeline (e.g. staging promote → verify → prod promote → verify-production). If defined, execute the steps in order. If none is defined, stop at merge and say so — do not invent a deploy.
3. Close linked issues with evidence.
4. **Every "verified" claim cites the command run and its raw output** (pass counts, exit codes, query results). If a check wasn't actually run, write NOT VERIFIED — never infer.
