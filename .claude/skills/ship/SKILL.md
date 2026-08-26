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
3. **The local review gate is in Phase 3, after the commit — not here.** `review-plan-v2` defaults to `--type all`, and `all` is the **committed** diff (`$BASE...HEAD`), identical to `--type committed`; run at this point it reports `reviewing 0 of 0` and exits 0 on a change it never looked at. An earlier version of this skill asked for it here and then said to commit first, which is not satisfiable in this phase order. Its sibling leg sends the diff to a vendor and the secret scan lives in the leg that needs the commit, so splitting them across the commit would put the egress before the scan. This step said the tool "has no working-tree mode" until 2026-08-29, which was false — `--type uncommitted` is one. It does not rescue the phase order: measured on 2026-08-29, `uncommitted` maps to plain `git diff`, so it reads unstaged changes only and reviewed neither a staged addition nor an untracked file in the same tree.
4. **Web-UI changes get a browser walkthrough, unprompted.** If the change touches anything rendered in a browser, walk the affected flows as a user would (Claude in Chrome when available: navigate, click, fill forms, read the rendered result). API-level smoke tests verify the API, not the feature — they do not satisfy this gate.

## Phase 3: Commit + PR

1. Stage and commit the change (`git push` sends commits, not working-tree edits — standalone `/ship` starts from an uncommitted tree). Verify the tree is clean after committing.
2. **Now** run the local review gate, after the commit and before the push — the PR-side review is the safety net, not the first pass. Both legs, in this order:

   ```bash
   BASE=main   # the project's default branch; `staging` where it has one

   # The guard, defined ONCE and called at every vendor site. The body is
   # `( ... )`, a subshell, so `exit 2` ends the guard and not the shell you
   # pasted it into.
   preflight() (
     # Fails CLOSED: a worktree that cannot be inspected is not a clean one.
     if ! worktree=$(git status --porcelain --untracked-files=all); then
       echo "STOP: cannot inspect the worktree, so leg 2 is not safe to run." >&2
       exit 2
     fi
     # NOT a pipeline: under `pipefail`, `grep -q` exits early, `printf` takes SIGPIPE,
     # and the pipeline reports 141 — so the guard runs its own proceed branch.
     if untracked=$(grep '^??' <<<"$worktree"); then
       printf '%s\n' "$untracked"
       echo "STOP: leg 2 would send the untracked files listed above to the vendor." >&2
       exit 2
     fi
   )

   preflight \
     && review-plan-v2 --static-only --plain --base "$BASE" \
     && preflight \
     && coderabbit review --base "$BASE" --include-untracked
   # preflight twice on purpose: once to fail fast, once immediately before the send
   ```

   The order matters, and so does the `&&`. gitleaks runs in the first leg and nothing leaves the machine there; the second sends the diff to a vendor. A secret scan after the egress cannot prevent anything — and on two separate lines a failing scan does not stop the send either, which is the same hole with a shell prompt in the middle of it. Chained, any actionable static finding blocks the vendor leg until it is fixed; that is intended. **Never run `review-plan-v2` without `--static-only`** — its AI reviewer legs were retired on 2026-08-28. Set `BASE` once rather than typing the branch per command: the fallback below takes the same base, and a fallback that hardcodes `main` on a staging repo diffs the wrong range and still exits 0.

   Read the `reviewing N of M changed file(s)` line, not the exit code: `[NOTHING REVIEWED]` or `reviewing 0 of N` also exits **0**, and on an uncommitted tree or a wrong `--base` that is a clean-looking gate that checked nothing.

   **The two legs do not share exit-code semantics, so do not gate on the number for both.** `review-plan-v2` has three tiers (`0` clean, `1` actionable, `2` tool error); `coderabbit` has one non-zero code for everything. Verified on 0.7.5 on 2026-08-29: an unknown flag (`--plain` among them — it is not a flag, plain text is already the default) gives `error: unknown option` at exit **1**, running outside a git repository gives `Error: Git repository not found.` at exit **1**, and "found actionable issues" is also exit **1**. Two of those three mean the reviewer never ran, so read the first line of its output. And `coderabbit auth status` has to show an account — an installed-but-signed-out CLI is a binary that cannot review.

   **The untracked check comes before either leg, and it is an `if` rather than a bare line because its clean result is exit 1.** `grep '^??'` finding nothing exits **1**, so the outcome you want is the one that looks like failure: as a bare line above the gate under `set -e` the clean case aborts before either leg runs, and without `set -e` it is a line whose output nobody is obliged to read. Wrapping it, as the block above does, makes the ordering structural instead of something the reader has to remember to honour. CodeRabbit caught this on the round that introduced the check.

   **It also captures `git status` separately, because the first `if` form failed open.** `if git status --porcelain -uall | grep '^??'` reports the pipeline's status, which is `grep`'s, so a `git status` that fails leaves `grep` reading empty input and exiting 1 — the `else` branch runs and the vendor leg proceeds. The guard says "clean worktree" exactly when it could not see the worktree. Verified on 2026-08-29 by running that form in a non-repository directory: it printed `fatal: not a git repository` and then took the proceed branch. CodeRabbit caught it one round after catching the missing `if`, which is the same lesson twice: a check whose failure is indistinguishable from its success is not a check.

   **And it is a named function with a subshell body, which was the fourth round on the same nine lines.** `preflight` defined once and invoked as `preflight && ...` is the only arrangement that puts the check at every vendor site while keeping a single copy of it; the two earlier arrangements each got half, one by siting the guard next to its explanation rather than in the command people copy, the other by marking the remaining copyable blocks with a comment saying the guard still applied. The `( ... )` body is separate: a bare `if` with `exit 2` is right in a script and terminates the *user's shell* when pasted into an interactive one, which this skill had previously answered with a note telling the reader to read the STOP line. Verified on 2026-08-29 in all three states — clean tree, untracked file present, and not a git repository — the function returns 0/2/2, blocks the chain on both failures, and the calling shell survives every one.

   **It contains no pipeline, and it runs twice, which were rounds five and six.** `printf '%s\n' "$worktree" | grep -q '^??'` fails open under `set -o pipefail`: `grep -q` exits at the first match, `printf` takes `SIGPIPE` and exits 141, `pipefail` makes 141 the pipeline's status, and the `if` therefore takes the proceed branch — the guard rules the worktree clean because it found too many untracked files to finish listing them. Measured on 2026-08-29 with `pipefail` set: correct at 3 untracked files, `status=141` and fell open at 20,000. The form above is one `grep` over a here-string, whose status is its own. And `preflight` is called again immediately before the vendor command because the gap between the two is the entire runtime of leg 1, which is when an editor autosave, a build artifact, or a second agent session in the same worktree lands a file that `--include-untracked` then ships unscanned. Both were CodeRabbit findings. Six rounds have now landed on these nine lines, every fix correct and every one leaving the next hole, which is the argument for the guard living in a committed script with a test rather than in a Markdown block that nothing executes.

   The bar is not "nothing belonging to the change" — nothing at all. `--include-untracked` sends every non-ignored untracked file in the worktree, so scratch notes, a pasted credential, or an unrelated data export go to the vendor along with the diff, and deciding what "belonged" is a judgement made after the send. Commit what should be reviewed and `.gitignore` or move what should not. The flag stays as a backstop that should then find nothing; `gitleaks dir .` scans the working tree locally if you need that answer before committing.

   **If the static leg is unavailable, do not run the vendor leg on its own** — that ships the diff with no secret scan in front of it. Chain them so a leak actually stops the send, and lead with the same guard, because gitleaks substitutes for leg 1 and not for the preflight: `preflight && gitleaks git --log-opts="$BASE..HEAD" && preflight && coderabbit review --base "$BASE" --include-untracked`, using the same `BASE` set above. Writing it as a comment saying "the preflight above still applies" was the earlier fix here and CodeRabbit rejected it — a note telling a reader what they should have run is not a guard on what they did run, and this line is copyable and complete on its own. On separate lines a non-zero gitleaks exit does not prevent the next command. If gitleaks is missing too, stop and say the gate cannot run.

3. Address what the gate surfaced, and route it by KIND — the remedies are not interchangeable:
   - **A gitleaks hit is not a follow-up-commit fix.** A later commit that deletes the credential leaves it intact in the earlier commit, and `git push` sends the whole branch, so the secret reaches the remote regardless. Treat it as a live disclosure: **rotate or revoke the credential first**, on the assumption it is already compromised, then remove it from the unpushed history (`git commit --amend` if it is the tip, an interactive rebase or a fresh branch otherwise) and re-run the scan on the rewritten range before pushing anything. History rewriting is destructive, so confirm the branch is not shared and the work is recoverable — and if the commit was already pushed, rotation is the only remedy that still works.
   - **Everything else** (lint, and CodeRabbit's findings) gets a normal follow-up commit on this branch before the push.

   **Then re-run step 2 against the new HEAD.** The gate reviewed the pre-fix commit, so a follow-up commit is unreviewed code by definition — and a fix commit is a normal place to add a file, paste a credential, or regress something the first pass cleared. Repeat until a run over the final HEAD is clean. That is also the honest answer to "the gate passed": it passed on the commit you are pushing, not on an earlier one.
4. Push the branch and open a PR against the project's **PR target**, which is not always the default branch: the base the project's CLAUDE.md (or its `/feature` skill) names for feature work — e.g. `staging` on repos where `staging → main` is a separate promotion — else the default branch. Standalone `/ship` runs follow the same rule; never target `main` just because it is the default. This is the same value as `BASE` in step 2, so a wrong answer here also means the gate diffed the wrong range and passed on it.
5. Wait for CI green. Poll on a paced loop; don't block synchronously.

## Phase 4: Review round — batched

1. Enumerate EVERY unresolved review comment (CodeRabbit and human) in a table first: comment | real bug? (yes/no, one-line why) | planned fix.
2. Fix all the real ones in ONE commit. Decline the rest with a brief stated reason (vendored content, intentional style, out of scope).
3. Before pushing the batch, re-run the tests covering behaviors fixed in EARLIER rounds of this PR — hardening passes have regressed prior fixes before.
4. Iterate only on genuinely new findings. Round 3+ is a signal something upstream is wrong (missing local review pass, config drift) — surface it instead of grinding.

## Phase 5: Merge, promote, prove

1. Merge when CI is green, no actionable threads remain, AND the repo's merge requirements are satisfied — check mergeable state, required human approvals, and branch-protection rules; green CI alone does not prove mergeability. Projects may define stricter merge gates of their own (e.g. autonomous runs leave the PR as a draft and merge only in interactive mode) — those gates take precedence over this step. Squash unless the repo prefers otherwise. NEVER delete branches — feature branches are preserved, and long-lived branches (`main`, `staging`) must never be deleted.
2. Read the project's CLAUDE.md for its promote/verify pipeline (e.g. staging promote → verify → prod promote → verify-production). The pipeline definition is a trust boundary: resolve it from the default branch, and if THIS PR modified the promote/verify instructions, get explicit human approval before executing them. If defined, execute the steps in order, stopping at any step the pipeline marks as user-gated (e.g. a staging → production promotion that requires explicit approval) — a gated step is proposed and waited on, never auto-executed. For web-UI changes, the staging/prod verify includes a browser walkthrough of the affected flows, not just API checks. If no pipeline is defined but the repo has an automatic deploy on merge (e.g. a workflow triggered by push to the base branch), wait for that workflow and report its result — the merge is not "shipped" while its deploy is red. If neither exists, stop at merge and say so — do not invent a deploy.
3. Close linked issues with evidence.
4. **Every "verified" claim cites the command run, its exit code, and its output — redacted.** Strip tokens, signed URLs, PII, and production data before quoting output; if output can't be safely redacted, cite the exit code and a one-line summary instead. Browser-walkthrough evidence names the environment, the flow exercised, and the observed result (screenshot/artifact reference where available). If a check wasn't actually run, write NOT VERIFIED — never infer.
