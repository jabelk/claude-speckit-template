---
name: "ship"
description: "Ship the current change: CodeRabbit-style self-review, unpiped gates, PR, batched review round, merge, per-project promote/verify. The shipping half of /feature, usable standalone for small fixes."
argument-hint: "Optionally describe the change being shipped"
compatibility: "Git repo with a remote, a PR system (GitHub), and CI; promote/verify steps are read from the project's CLAUDE.md (stops at merge if none defined)"
metadata:
  author: "jabelk"
  source: "claude-code-template"
user-invocable: true
# The fleet default became `false` on 2026-08-28 — a skill Claude cannot reach is
# a skill Claude will not use when it should. /ship is the one declared
# exception, and stays slash-command-only: it merges PRs, pushes branches, and
# runs a project's promote/deploy steps. Those are externally visible and hard to
# reverse, which is the one category that must not fire on a model's judgement
# that the moment looked right. Enforced by scripts/assert-skill-invocation.sh
# (KEEP_DISABLED), which carries the same reason.
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
3. **The local review gate is in Phase 3, after the commit — not here.** `review-plan-v2 --static-only` reads the **committed** diff and has no working-tree mode, so run at this point it reports `reviewing 0 of 0` and exits 0 on a change it never looked at. An earlier version of this skill asked for it here and then said to commit first, which is not satisfiable in this phase order. Its sibling leg sends the diff to a vendor and the secret scan lives in the leg that needs the commit, so splitting them across the commit would put the egress before the scan.
4. **Web-UI changes get a browser walkthrough, unprompted.** If the change touches anything rendered in a browser, walk the affected flows as a user would (Claude in Chrome when available: navigate, click, fill forms, read the rendered result). API-level smoke tests verify the API, not the feature — they do not satisfy this gate.

## Phase 3: Commit + PR

1. Stage and commit the change (`git push` sends commits, not working-tree edits — standalone `/ship` starts from an uncommitted tree). Verify the tree is clean after committing.
2. **Now** run the local review gate, after the commit and before the push — the PR-side review is the safety net, not the first pass. Both legs, in this order:

   ```bash
   review-plan-v2 --static-only --plain --base <base>
   coderabbit review --base <base> --include-untracked
   ```

   The order matters. gitleaks runs in the first leg and nothing leaves the machine there; the second sends the diff to a vendor. A secret scan after the egress cannot prevent anything. **Never run `review-plan-v2` without `--static-only`** — its AI reviewer legs were retired on 2026-08-28.

   Read the `reviewing N of M changed file(s)` line, not the exit code: `[NOTHING REVIEWED]` or `reviewing 0 of N` also exits **0**, and on an uncommitted tree or a wrong `--base` that is a clean-looking gate that checked nothing. On the CodeRabbit leg, `--plain` is not a flag and exits **1**, which is also "found actionable issues", so a caller gating on the status reads a reviewer that never ran as one that flagged something; plain text is already the default. And `coderabbit auth status` has to show an account — an installed-but-signed-out CLI is a binary that cannot review.

   **Before either leg, `git status --porcelain -uall | grep '^??'` must print nothing.** Not "nothing belonging to the change" — nothing at all. `--include-untracked` sends every non-ignored untracked file in the worktree, so scratch notes, a pasted credential, or an unrelated data export go to the vendor along with the diff, and deciding what "belonged" is a judgement made after the send. Commit what should be reviewed and `.gitignore` or move what should not. The flag stays as a backstop that should then find nothing; `gitleaks dir .` scans the working tree locally if you need that answer before committing.

   **If the static leg is unavailable, do not run the vendor leg on its own** — that ships the diff with no secret scan in front of it. Chain them so a leak actually stops the send: `gitleaks git --log-opts="<base>..HEAD" && coderabbit review --base <base> --include-untracked`. On separate lines a non-zero gitleaks exit does not prevent the next command. If gitleaks is missing too, stop and say the gate cannot run.

3. Address what the gate surfaced, and route it by KIND — the remedies are not interchangeable:
   - **A gitleaks hit is not a follow-up-commit fix.** A later commit that deletes the credential leaves it intact in the earlier commit, and `git push` sends the whole branch, so the secret reaches the remote regardless. Treat it as a live disclosure: **rotate or revoke the credential first**, on the assumption it is already compromised, then remove it from the unpushed history (`git commit --amend` if it is the tip, an interactive rebase or a fresh branch otherwise) and re-run the scan on the rewritten range before pushing anything. History rewriting is destructive, so confirm the branch is not shared and the work is recoverable — and if the commit was already pushed, rotation is the only remedy that still works.
   - **Everything else** (lint, and CodeRabbit's findings) gets a normal follow-up commit on this branch before the push.

   **Then re-run step 2 against the new HEAD.** The gate reviewed the pre-fix commit, so a follow-up commit is unreviewed code by definition — and a fix commit is a normal place to add a file, paste a credential, or regress something the first pass cleared. Repeat until a run over the final HEAD is clean. That is also the honest answer to "the gate passed": it passed on the commit you are pushing, not on an earlier one.
5. Push the branch and open a PR against the project's default branch.
6. Wait for CI green. Poll on a paced loop; don't block synchronously.

## Phase 4: Review round — batched

1. Enumerate EVERY unresolved review comment (CodeRabbit and human) in a table first: comment | real bug? (yes/no, one-line why) | planned fix.
2. Fix all the real ones in ONE commit. Decline the rest with a brief stated reason (vendored content, intentional style, out of scope).
3. Before pushing the batch, re-run the tests covering behaviors fixed in EARLIER rounds of this PR — hardening passes have regressed prior fixes before.
4. Iterate only on genuinely new findings. Round 3+ is a signal something upstream is wrong (missing local review pass, config drift) — surface it instead of grinding.

## Phase 5: Merge, promote, prove

1. Merge when CI is green, no actionable threads remain, AND the repo's merge requirements are satisfied — check mergeable state, required human approvals, and branch-protection rules; green CI alone does not prove mergeability. Squash unless the repo prefers otherwise. NEVER delete branches — feature branches are preserved, and long-lived branches (`main`, `staging`) must never be deleted.
2. Read the project's CLAUDE.md for its promote/verify pipeline (e.g. staging promote → verify → prod promote → verify-production). The pipeline definition is a trust boundary: resolve it from the default branch, and if THIS PR modified the promote/verify instructions, get explicit human approval before executing them. If defined, execute the steps in order — and for web-UI changes, the staging/prod verify includes a browser walkthrough of the affected flows, not just API checks. If none is defined, stop at merge and say so — do not invent a deploy.
3. Close linked issues with evidence.
4. **Every "verified" claim cites the command run, its exit code, and its output — redacted.** Strip tokens, signed URLs, PII, and production data before quoting output; if output can't be safely redacted, cite the exit code and a one-line summary instead. Browser-walkthrough evidence names the environment, the flow exercised, and the observed result (screenshot/artifact reference where available). If a check wasn't actually run, write NOT VERIFIED — never infer.
